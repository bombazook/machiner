# frozen_string_literal: true

require "forwardable"

module Machiner
  module States
    def self.extended(base)
      base.extend SingletonMethods
      base.include InstanceMethods
    end

    module SingletonMethods
      def state_container
        @state_container ||= Container.new
      end

      def meta(**meta_hash)
        @meta = meta_hash || {}
      end

      def included(base)
        super
        base.extend SingletonMethods
      end

      def inherited(base)
        super
        base.extend SingletonMethods
      end

      def self.extended(base)
        return unless base.ancestors.include?(InstanceMethods)

        base_container = base.ancestors[1..].detect { |i| i.respond_to? :state_container }&.state_container
        return unless base_container

        return if base.state_container.supercontainers.include?(base_container)

        base.state_container.supercontainers << base_container
      end

      def state(key, value = nil, **meta, &block)
        meta = @meta.merge(meta) if @meta
        state_container.register(key, value, **meta, &block)
      end

      def state_names
        state_container.keys.uniq
      end

      def state?(state_name, *data, **meta)
        callable = state_container[state_name, **meta]
        return false unless callable

        if callable && callable.arity > data.size
          callable.call(*data.clone, self)
        else
          callable.call(*data.clone)
        end
      end

      def states(data)
        state_container.keys.select { |state| state_container[state].call(data) }
      end
    end

    module InstanceMethods
      extend Forwardable

      def_delegators "self.class", :state?, :state_names, :states
    end
  end
end
