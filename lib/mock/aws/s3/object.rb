require 'fileutils'
require 'ostruct'

module AWS
  module S3

    class S3Object
      class << self

        def value(key, bucket = nil, options = {}, &block)
          data = File.open(path!(bucket, key, options)) {|f| f.read}
          Value.new OpenStruct.new(:body=>data)
        end

				def url_for(key, bucket = nil, options={})
          "file://#{File.expand_path(path!(bucket, key))}"
				end

				def find(key, bucket = nil)
					raise NoSuchKey.new("No such key `#{key}'", bucket) unless exists?(key, bucket)
					bucket = Bucket.new(:name => bucket)
					object = bucket.new_object
					object.key = key
					object
				end

        def stream(key, bucket = nil, options = {}, &block)
          path = path!(bucket, key)
          FileUtils.makedirs File.dirname(path)
          File.open(path) do |f|
            if block
              read_chunks(f, &block)
            else
              f.read
            end
          end
        end

        # Makes a copy of the object with <tt>key</tt> to <tt>copy_key</tt>, preserving the ACL of the existing object if the <tt>:copy_acl</tt> option is true (default false).
        def copy(key, copy_key, bucket = nil, options = {})
          bucket          = bucket_name(bucket)
          source_key      = path!(bucket, key)
          target_key      = path!(bucket, copy_key)
          FileUtils.makedirs File.dirname(target_key)
          FileUtils.cp_r source_key, target_key
        end

        def about(key, bucket)
          return nil unless exists?(key, bucket)
          {"content-length" => File.size(path!(bucket, key)).to_s}
        end

        def exists?(key, bucket = nil)
          File.exists?(path!(bucket, key))
        end

        def delete(key, bucket = nil, options = {})
          File.unlink path!(bucket, key, options)
        end

        def store(key, data, bucket = nil, options = {})
          validate_key!(key)
          # Must build path before infering content type in case bucket is being used for options
          path = path!(bucket, key, options)
          infer_content_type!(key, options)

          FileUtils.makedirs File.dirname(path)
          File.open(path, 'wb') do |f|
            if data.respond_to?(:read)
              FileUtils.copy_stream(data, f)
            else
              f.write data
            end
          end
        end
        alias_method :create, :store
        alias_method :save,   :store

        TEMP_PATH = begin
          if defined?(::Rails)
            Rails.root.to_s
          else
            '.'
          end
        end

        def path!(bucket, name, options = {}) #:nodoc:
          # We're using the second argument for options
          if bucket.is_a?(Hash)
            options.replace(bucket)
            bucket = nil
          end
          TEMP_PATH.clone << File.join('/tmp', 'mock-aws-s3', bucket_name(bucket), name)
        end

        private

        def read_chunks(f)
          yield f.read(4096) until f.eof?
        end
      end
    end
  end
end
