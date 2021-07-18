# frozen_string_literal: true

require_relative "machiner/version"

module Machiner
  class Error < StandardError; end

  class WrongTransitionError < Error; end

  class WrongStateError < Error; end

  autoload :Container, "machiner/container"
  autoload :States, "machiner/states"
  autoload :Transitions, "machiner/transitions"
end
