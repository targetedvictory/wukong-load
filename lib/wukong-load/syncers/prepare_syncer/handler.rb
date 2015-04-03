require_relative('metadata_handler')
require 'wukong-load/dumpers/file_dumper'
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
          (extend settings[:ordered_handler].nil? ? OrderedHandler : Object.const_get(settings[:ordered_handler])) if settings[:ordered]
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
          file_dumper = file_dumper(original)

          if !settings[:gzip_output]  && (!file_dumper.compressed_file? || (file_dumper.compressed_file? && !settings[:uncompress_input]))
            create_hardlink(original, path_for(original))
          else
            copy_or_uncompress_input_and_gzip_output(file_dumper)
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

        # The file dumper that will be used to dump the file into the
        # command-line later (e.g: `split`).
        #
        # The file dumper is configured with the `clean` option but
        # without the `decorate` option.
        #
        # @param [Pathname] original
        # @return [FileDumper]
        def file_dumper original
          FileDumper.new(input: original, clean: true)
        end

        def copy_or_uncompress_input_and_gzip_output original_file_dumper
          copy_path = path_for(original_file_dumper.file)
          copy_path = Pathname.new(copy_path.to_path + ".gz") if settings[:gzip_output]
          mkdir_p(copy_path.dirname)

          copy_command = file_dumper.dump_command
          if settings[:gzip_output]
            copy_command += " | gzip > #{copy_path.to_path}"
          else
            copy_command += " > #{copy_path.to_path}"
          end
          
          log.debug("Processing file: #{original_file_dumper.file} -> #{copy_path}")
          FileUtils.cd(copy_path.dirname) do
            unless settings[:dry_run]
              raise Error.new("Copy command exited unsuccessfully") unless system(copy_command)
            end
          end

          process_metadata_for(copy_path) if settings[:metadata] && (! settings[:dry_run])
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

