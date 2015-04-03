module Wukong
  module Load
    class PrepareSyncer

      # Can be included into another Handler class to make that
      # handler create a strict ordering for files in its output
      # directory.
      module OrderedHandler
        
        # Return the output path for the given `original` file.
        #
        # @param [Pathname] original
        # @return [Pathname]
        def path_for original
          current_output_directory.join(daily_directory_for(file_time(original), original)).join(slug_for(processing_time, original))
        end

        # Return the daily directory for the given `time`.
        #
        # @param [Time] time
        # @return [String]
        def daily_directory_for time, original
          File.join(top_level_of(original, settings[:input]), time.strftime("%Y/%m/%d"))
        end

        # Return the basename to use for the given `time` for given
        # `original` file.
        def slug_for(time, original)
          [
           time.strftime("%Y%m%d-%H%M%S"),
           counter.to_s,
           relative_path_of(original, settings[:input]).to_s.gsub(%r{/},'-'),
          ].join('-')
        end
        
        def file_time original
          File.mtime(original.to_path)
        end

        def processing_time
          @processing_time ||= Time.now.utc
        end
      end
    end
  end
end

