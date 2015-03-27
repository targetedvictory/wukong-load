require_relative('metadata_handler')
module Wukong
  module Load
    class PrepareSyncer

      autoload :OrderedHandler, 'wukong-load/syncers/prepare_syncer/ordered_handler'

      # Base class for other handlers to subclass.
      class Handler

        # The PrepareSyncer this Handler is for.
        attr_accessor :syncer

        # Settings this handler was created with, probably inherited
        # from the PrepareSyncer that created it.
        attr_accessor :settings

        # A counter that increments for each input file processed.
        attr_accessor :counter

        include Logging
        include MetadataHandler

        # Create a new Handler with the given `settings`.
        #
        # @param [PrepareSyncer] syncer the syncer this handler is for
        # @param [Configliere::Param] settings
        # @option settings [Pathname] :input the input directory
        # @option settings [Array<Pathname>] :output the output directories
        # @option settings [true, false] :dry_run log what would be done instead of doing it
        # @option settings [true, false] :ordered create totally ordered output
        # @option settings [true, false] :metadata create metadata files for each output file
        def initialize syncer, settings
          self.syncer   = syncer
          self.settings = settings
          self.counter  = 0
          self.counter  = rand(settings[:output].size) if settings[:output] && settings[:output].size > 1
          extend (settings[:dry_run] ? FileUtils::NoWrite : FileUtils)
          extend OrderedHandler if settings[:ordered]
        end

        # Process the `original` file in the input directory.
        #
        # @param [Pathname] original
        def process original
          before_process(original)
          process_input(original)
          after_process(original)
          true
        rescue => e
          on_error(original, e)
          false
        end

        # Creates a hardlink in the `output` directory with the same
        # relative path as `path` in the input directory.
        #
        # @param [Pathname] original
        def process_input original
          if uncompress_needed?(original)
            uncompress_and_gzip(original)
          else
            create_hardlink(original, path_for(original))
          end
        end

        module Hooks
          # Run before processing each file.
          #
          # @param [Pathname] original the original file in the input directory
          def before_process original
          end
          
          # Run after successfully processing each file.
          #
          # By default it increments the #counter.
          #
          # @param [Pathname] original the original file in the input directoryw
          def after_process original
            self.counter += 1
          end
          
          # Run upon an error during processing.
          #
          # @param [Error] error
          # @param [Pathname] original the original file in the input directoryw
          def on_error original, error
            log.error("Could not process <#{original}>: #{error.class} -- #{error.message}")
          end
        end
        include Hooks
        
        # Creates a hardlink at `copy` pointing to `original`.
        #
        # @param [Pathname] original
        # @param [Pathname] copy
        def create_hardlink original, copy
          mkdir_p(copy.dirname)
          log.debug("Linking #{copy} -> #{original}")
          ln(original, copy, force: true)
          process_metadata_for(copy) if settings[:metadata]
        end

        def uncompress_needed? original
          case original.basename.to_s
          when /\.zip$/ then true
          else false
          end
        end

        def uncompress_and_gzip original
          copy_dir = path_for(original).dirname
          copy_filename = ""
          mkdir_p(copy_dir)

          original_filename = original.basename.to_s
          unzip_command = ""

          FileUtils.cd(copy_dir) do
            case original_filename
            #TO-DO: finish .tar files, .bz2
            #when /\.tar\.gz$/, /\.tgz$/   then "tar -xvfz"
            #when /\.tar\.bz2$/, /\.tbz2$/ then "tar -xvfj -C #{copy.dirname.to_s}"
            #when /\.bz2$/                 then "bzip2 -dk"
            when /\.zip$/ then 
              unzip_command = "unzip #{original.to_path} -d #{copy_dir.to_s}"
              copy_filename = original_filename[0...-4]
            end
            
            raise Error.new("Unzip command exited unsuccessfully") unless system(unzip_command)

            if settings[:gzip_output]
              raise Error.new("Gzip command exited unsuccessfully") unless system("gzip #{Shellwords.escape(copy_filename)}")
            end
          end

          process_metadata_for(Pathname.new("#{copy_dir}/#{copy_filename}")) if settings[:metadata]
        end

        # Return the current output directory, chosen by cycling
        # through the given output directories based on the value of
        # the current #counter.
        #
        # @return [Pathname]
        def current_output_directory
          settings[:output][self.counter % settings[:output].size]
        end

        # Return a path in an `output` directory that has the same
        # relative path as `original` does in the input directory.
        #
        # The `output` directory chosen will cycle through the given
        # output directories as the #counter increments.
        #
        # @param [Pathname] original
        # @return [Pathname]
        def path_for original
          current_output_directory.join(relative_path_of(original, settings[:input]))
        end
        
        # Return the path of `file` relative to the containing `dir`.
        #
        # @param [Pathname] file
        # @param [Pathname] dir
        # @return [Pathname]
        def relative_path_of file, dir
          file.relative_path_from(dir)
        end

        # Return the path relative to the `input` directory of the
        # `original` path.
        #
        # @param [Pathname] original
        # @return [Pathname]
        def fragment_for original
          relative_path_of(original, settings[:input])
        end

        # Returns the top-level directory of the `file`, relative to
        # `dir`.
        #
        # If the `file` is in `dir` itself, and not a subdirectory,
        # returns the string "root".
        #
        # @param [Pathname] file
        # @param [Pathname] dir
        # @return [String, "root"]
        def top_level_of(file, dir)
          top_level, rest = relative_path_of(file, dir).to_s.split('/', 2)
          rest ? top_level : 'root'
        end
        
      end
    end
  end
end

