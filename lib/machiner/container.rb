# frozen_string_literal: true

module Machiner
  class Container
    attr_accessor :supercontainers

    def initialize(supercontainer = nil)
      @container = {}
      @supercontainers = []
      @supercontainers << supercontainer if supercontainer
    end

    def register(key, value = nil, **meta, &block)
      @container[[key.to_s, meta]] = block || value
    end

    def [](key_name, **meta)
      full_key = @container.keys.detect do |k|
        check_key_name_and_meta(k, key_name, meta)
      end
      return @container[full_key] if full_key

      @supercontainers.detect { |i| i[key_name, **meta] }&.send(:[], key_name, **meta)
    end

    def filtered_keys(key_name, **meta)
      local_keys = @container.keys.select do |k|
        check_key_name_and_meta(k, key_name, meta)
      end
      return local_keys unless local_keys.empty?

      @supercontainers.flat_map { |i| i.filtered_keys(key_name, **meta) }
    end

    def keys
      full_keys.map(&:first)
    end

    def full_keys
      @container.keys + @supercontainers.flat_map(&:full_keys)
    end

    def get_by_full_key(key)
      @container[key] || @supercontainers.detect { |i| i.get_by_full_key(key) }&.get_by_full_key(key)
    end

    private

    def check_key_name_and_meta(key, key_name, meta)
      key.first == key_name.to_s && meta.all? do |meta_key, value|
        key.last && key.last[meta_key] == value
      end
    end
  end
end
