# frozen_string_literal: true

require "forwardable"

module Machiner
  module Transitions
    def self.extended(base)
      base.extend SingletonMethods
      base.include InstanceMethods
    end

    module SingletonMethods
      def transition_container
        @transition_container ||= Container.new
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

        base_container = base.ancestors[1..].detect { |i| i.respond_to? :transition_container }&.transition_container
        return unless base_container

        return if base.transition_container.supercontainers.include?(base_container)

        base.transition_container.supercontainers << base_container
      end

      def transition(event_name, path, meta = {}, &block)
        meta = @meta.merge(meta) if @meta
        from_state = path.keys.first
        to_state = path.values.first
        meta.merge!(from: from_state, to: to_state)
        transition_container.register(event_name, **meta, &block)
      end

      def transition_names
        transition_container.keys.uniq
      end

      def transition?(event_name, *data, **meta)
        transition_keys = transition_container.filtered_keys(event_name, **meta)
        transition_keys.any? do |key|
          transition_key_check(key, *data)
        end
      end

      def transitions(*data, **meta)
        transition_container.full_keys.select { |key| transition_key_check(key, *data, **meta) }
      end

      def call(event_name, *data, params: {}, **meta)
        raise ArgumentError if data.empty?

        transition_keys = transition_container.filtered_keys(event_name, **meta)
        raise WrongTransitionError if transition_keys.empty?

        transition_key = transition_keys.detect do |key|
          transition_key_check(key, *data)
        end
        raise WrongStateError unless transition_key

        call_transition_by_full_key(transition_key, *data, **params)
      end

      def safe_call(event_name, *data, params: {}, **meta)
        transition_keys = transition_container.filtered_keys(event_name, **meta)
        return (data.size == 1 ? data[0] : data) if transition_keys.empty?

        transition_key = transition_keys.detect do |key|
          transition_key_check(key, *data)
        end
        return (data.size == 1 ? data[0] : data) unless transition_key

        call_transition_by_full_key(transition_key, *data, **params)
      end

      private

      def call_transition_by_full_key(transition_key, *data, **params)
        transition = transition_container.get_by_full_key(transition_key)
        if transition.arity > data.size
          transition.call(*data.map(&:clone), self, **params)
        else
          transition.call(*data.map(&:clone), **params)
        end
      end

      def transition_key_check(key, *data)
        meta = key.last.except(:from, :to)
        [key.last[:from]].flatten.all? { |state| state?(state, *data, **meta) }
      end
    end

    module InstanceMethods
      extend Forwardable

      def_delegators "self.class", :transition?, :transition_names, :transitions, :call, :safe_call
    end
  end
end
