module Wukong
  module Load
    class PrepareSyncer

      module OrderedHandlerBase
        # Return the daily directory for the given `time`.
        #
        # @param [Time] time
        # @return [String]
        def daily_directory_for subdirectory, original
          File.join(top_level_of(original, settings[:input]), subdirectory)
        end

        def file_time original
          time_str = original.basename.to_s.scan(/[1,2]{1}[0,1]{1}\d{6}/).last
          if time_str
            DateTime.strptime(time_str[1], '%Y%m%d')
          else
            File.mtime(original.to_path)
          end
        end

        def processing_time
          @processing_time ||= Time.now.utc
        end
      end

      # Can be included into another Handler class to make that
      # handler create a strict ordering for files in its output
      # directory.
      module OrderedHandler
        include OrderedHandlerBase
        
        # Return the output path for the given `original` file.
        #
        # @param [Pathname] original
        # @return [Pathname]
        def path_for original
          current_output_directory.join(daily_directory_for((settings[:ordered_by_processing_time] ? processing_time : file_time(original)).strftime(settings[:ordered_time_pattern]), original)).join(slug_for(processing_time, original))
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
      end
    end
  end
end

