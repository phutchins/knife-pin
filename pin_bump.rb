# Knife pin bump
# Bumps the version of a cookbook in a run list assigned to multiple nodes using a knife search
# Philip Hutchins [ Fri Jun 14 15:27:03 EDT 2013 ]

# TODO
# Model the commands and help after existing knife plugin (Mark mentioned)
# Create pin show - List all the pins for search and cookbook

require 'chef'
require 'chef/knife'

class Chef
  class Knife
    class PinBump < Chef::Knife

      deps do
        require 'chef/search/query'
        require 'chef/knife/search'
        require 'chef/node'
      end

      banner 'knife pin bump -C COOKBOOK -s KNIFE_SEARCH -p PIN_TO_VERSION'

      option :dry_run,
        :short => "-d",
        :long => "--dryrun",
        :boolean => true,
        :default => false,
        :description => "Do not make any changes but show what will be done"

      option :cookbook_to_pin,
        :short => '-C COOKBOOK',
        :long => '--cookbook COOKBOOK',
        :description => 'The cookbook to update in the runlist'

      option :knife_search,
        :short => '-s \"KNIFE SEARCH\"',
        :long => '--search \'KNIFE SEARCH\'',
        :description => 'Search to use to find nodes on which to update specified cookbook.'

      option :new_pin_version,
        :short => '-p VERSION',
        :long => '--pin VERSION',
        :description => 'The new version number to pin specified cookbook to'

      def run
        unless @cookbook_to_pin = config[:cookbook_to_pin]
          ui.error 'You need to specify a cookbook name'
          exit 1
        end

        unless @knife_search = config[:knife_search]
          ui.error 'You need to specify a knife search'
          exit 1
        end

        unless @new_pin_version = config[:new_pin_version]
          ui.error 'You need to specify a new version to pin to'
          exit 1
        end

        dry_run = config[:dry_run]
        if dry_run 
          ui.msg "DRY RUN!"
        end

        query_nodes = Chef::Search::Query.new
        query_nodes.search('node', @knife_search) do |node_item|
          run_list = node_item.run_list
          new_run_list = run_list.map do |item|
            item.to_s.gsub(/(recipe\[#{@cookbook_to_pin}(?:::[^@]*)?)(?:@[^\]]*)?\]/, 
                           "\\1@#{@new_pin_version}]") 
          end
          ui.msg "#{node_item.name}: - New Run List: #{new_run_list.inspect}"
          unless dry_run
            node_item.run_list(new_run_list)
            node_item.save
          end
        end
      end
    end
  end
end
