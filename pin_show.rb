# Knife pin bump
# Bumps the version of a cookbook in a run list assigned to multiple nodes using a knife search
# Philip Hutchins [ Fri Jun 14 15:27:03 EDT 2013 ]

# TODO
# Model the commands and help after existing knife plugin (Mark mentioned)

require 'chef'
require 'chef/knife'

class Chef
  class Knife
    class PinShow < Chef::Knife

      deps do
        require 'chef/search/query'
        require 'chef/knife/search'
        require 'chef/node'
      end

      banner 'knife pin show -C COOKBOOK -s KNIFE_SEARCH'

      option :cookbook_to_pin,
        :short => '-C COOKBOOK',
        :long => '--cookbook COOKBOOK',
        :description => 'The cookbook to update in the runlist'

      option :knife_search,
        :short => '-s \"KNIFE SEARCH\"',
        :long => '--search \'KNIFE SEARCH\'',
        :description => 'Search to use to find nodes on which to update specified cookbook.'

      def run
        unless @cookbook_to_pin = config[:cookbook_to_pin]
          ui.error 'You need to specify a cookbook name'
          exit 1
        end

        unless @knife_search = config[:knife_search]
          ui.error 'You need to specify a knife search'
          exit 1
        end

        query_nodes = Chef::Search::Query.new
        query_nodes.search('node', @knife_search) do |node_item|
          run_list = node_item.run_list
          new_run_list = run_list.map do |item|
            item.to_s.match /(recipe\[#{@cookbook_to_pin}(?:::[^@]*)?)(?:@[^\]]*)?\]/
          end
          pin_ver = $3 || "NO PIN"
          ui.msg "#{node_item.name}: - Current pin for #{$1}]: #{pin_ver}"
        end
      end
    end
  end
end
