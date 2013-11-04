# Knife mass vi
# Allows you to use VIM to edit a run list for multiple nodes derived from a chef search
# Philip Hutchins [ Fri Jun 14 15:27:03 EDT 2013 ]

require 'chef'
require 'chef/knife'

class Chef
  class Knife
    class MassVi < Chef::Knife

      deps do
        require 'chef/search/query'
        require 'chef/knife/search'
        require 'chef/node'
        require 'chef/json_compat'
      end

      attr_reader :node
      attr_reader :ui
      attr_reader :config

      #def initialize(node, ui, config)
      #  @node, @ui, @config = node, ui, config
      #end

      banner 'knife mass vi -s KNIFE_SEARCH'

      option :dry_run,
        :short => "-d",
        :long => "--dryrun",
        :boolean => true,
        :default => false,
        :description => "Do not make any changes but show what will be done"

      option :knife_search,
        :short => '-s \"KNIFE SEARCH\"',
        :long => '--search \'KNIFE SEARCH\'',
        :description => 'Search to use to find nodes on which to update specified cookbook.'

      option :node_runlist_to_use,
        :short => '-n NODENAME',
        :long => '--node NODENAME',
        :description => 'Optionally specify a node to get the initial runlist to be edited'


      def edit_node_runlist
        abort "You specified the --disable_editing option, nothing to edit" if config[:disable_editing]
        assert_editor_set!

        updated_node_data = edit_data(view)
        apply_updates(updated_node_data)
        @updated_node
      end

      def edit_data(text)
        edited_data = tempfile_for(text) {|filename| system("#{config[:editor]} #{filename}")}
        Chef::JSONCompat.from_json(edited_data)
      end

      def view
        result = {}
        result["run_list"] = node_name.run_list
        Chef::JSONCompat.to_json_pretty(result)
      end

      def apply_updates(updated_data)
        @updated_node = Node.new.tap do |n|
          puts updated_data["run_list"]
          n.run_list( updated_data["run_list"])
        end
      end

      def updated?
        pristine_copy = Chef::JSONCompat.from_json(Chef::JSONCompat.to_json(node), :create_additions => false)
        updated_copy  = Chef::JSONCompat.from_json(Chef::JSONCompat.to_json(@updated_node), :create_additions => false)
        unless pristine_copy == updated_copy
          updated_properties = %w{run_list}.reject do |key|
             pristine_copy[key] == updated_copy[key]
          end
        end
        ( pristine_copy != updated_copy ) && updated_properties
      end

      def abort(message)
        ui.error(message)
        exit 1
      end

      def assert_editor_set!
        unless config[:editor]
          abort "You must set your EDITOR environment variable or configure your editor via knife.rb"
        end
      end

      def tempfile_for(data)
        # TODO: include useful info like the node name in the temp file
        # name
        basename = "knife-edit-" << rand(1_000_000_000_000_000).to_s.rjust(15, '0') << '.json'
        filename = File.join(Dir.tmpdir, basename)
        File.open(filename, "w+") do |f|
          f.sync = true
          f.puts data
        end

        yield filename

        IO.read(filename)
      ensure
        File.unlink(filename)
      end

      def run
        unless @knife_search = config[:knife_search]
          ui.error 'You need to specify a knife search'
          exit 1
        end

        # List all hosts found then ask if ready to make edits
        # or prompt for a number representing a certain host to edit

        query_nodes = Chef::Search::Query.new
        #query_nodes_results = query_nodes.search('node', @knife_search) 

        count = 0
        #query_nodes_results do |node_item|
        query_nodes.search('node', @knife_search) do |node_item|
          if count == 0
            @reference_node = node_item
          end
          ui.warn "#{count} - #{node_item.name}"
          count+=1
        end

        confirm = ui.confirm "Proceed with edit?"

        if !@node_runlist_to_use
          @node_name = @reference_node
        end

        updated_node_runlist = edit_node_runlist
        #query_nodes_results.each do |node_item|
        query_nodes.search('node', @knife_search) do |node_item|
          @node = node_item
          apply_updates(updated_node_runlist)
        end
      end

      def node_name
        @node_runlist_to_use ||= @node_name
      end

      def node
        @node ||= Chef::Node.load(node_name)
      end

    end
  end
end
