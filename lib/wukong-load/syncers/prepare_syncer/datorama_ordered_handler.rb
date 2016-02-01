require 'wukong-load/syncers/prepare_syncer/ordered_handler'
module Wukong
  module Load
    class PrepareSyncer

      # Can be included into another Handler class to make that
      # handler create a strict ordering for files in its output
      # directory.
      module DatoramaOrderedHandler
        include OrderedHandlerBase
        
        # Return the output path for the given `original` file.
        #
        # @param [Pathname] original
        # @return [Pathname]
        def path_for original
          binding.pry
          current_output_directory.join(daily_directory_for(file_time(original).strftime(settings[:ordered_time_pattern]), original)).join(File.mtime(original.to_path).to_i.to_s).join(slug_for(processing_time, original))
        end
      end
    end
  end
end