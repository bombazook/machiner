# frozen_string_literal: true

require "byebug"

module BoatStates
  extend Machiner::States

  meta key: :base

  state :on_water, ->(b) { b[:docked] != true }
  state :in_dock, ->(b) { b[:docked] == true }
  state :stays, ->(b) { !b[:state] || b[:state] == "stays" }
  state :ready_for_dock, ->(b, m) { m.state?(:on_water, b) }
end

module BoatTransitions
  extend Machiner::Transitions

  meta key: :base

  transition :dock, ready_for_dock: :in_dock do |b|
    b[:docked] = true
    b.delete(:state)
    b
  end

  transition :undock, in_dock: :on_water do |b|
    b[:docked] = false
    b
  end
end

module PaddleboatStates
  include BoatStates

  meta key: :paddleboat

  state :ready, ->(b, m) { !m.state?(:docked, b) && m.state?(:stays, b) && m.state?(:paddles_ready, b) }
  state :paddles, ->(b) { b[:state] == "paddles" }
  state :soft_paddles, ->(b) { !b[:paddles] || b[:paddles] == "soft" }
  state :paddles_ready, ->(b) { b[:paddles] == "on water" }
  state :ready_for_dock, ->(b, m) { m.state?(:on_water, b) && m.state?(:soft_paddles, b) }
end

module PaddleboatTransitions
  include BoatTransitions

  meta key: :paddleboat

  transition :go, ready: :paddles do |b|
    b[:state] = "paddles"
    b
  end

  transition :stop, paddles: :stays do |b|
    b[:state] = "stays"
    b
  end

  transition :setup_paddles, soft_paddles: :paddles_ready do |b|
    b[:paddles] = "on water"
    b
  end

  transition :paddles_up, paddles_ready: :soft_paddles do |b|
    b[:paddles] = "soft"
    b
  end

  transition :dock, ready_for_dock: :docked do |b, m|
    b = m.call(:dock, b, key: :base)
    b.delete(:paddles)
    b
  end
end

module SailboatStates
  include BoatStates

  meta key: :sailboat

  state :ready, ->(b, m) { !m.state?(:docked, b) && m.state?(:stays, b) && m.state?(:sail_ready, b) }
  state :sail_down, ->(b) { !b[:sail] || b[:sail] == "down" }
  state :sail_ready, ->(b) { b[:sail] == "ready" }
  state :sails, ->(b) { b[:state] == "sails" }
  state :ready_for_dock, ->(b, m) { m.state?(:on_water, b) && m.state?(:sail_down, b) }
end

module SailboatTransitions
  include BoatTransitions

  meta key: :sailboat

  transition :go, ready: :sails do |b|
    b[:state] = "sails"
    b
  end

  transition :stop, sails: :stays do |b|
    b[:state] = "stays"
    b
  end

  transition :set_sail, sail_down: :sail_ready do |b|
    b[:sail] = "ready"
    b
  end

  transition :take_away_sail, sail_ready: :sail_down do |b|
    b[:sail] = "down"
    b
  end

  transition :dock, ready_for_dock: :docked do |b, m|
    b = m.call(:dock, b, key: :base)
    b.delete(:sail)
    b
  end
end

class PaddleboatMachine
  include PaddleboatStates
  include PaddleboatTransitions
end

puts "paddleboat cruise"
boat = { name: "Paddleboat 1", docked: true }
puts boat
machine = PaddleboatMachine.new
begin
  machine.call(:go, boat)
rescue Machiner::WrongStateError
  puts "Can't go in docked state"
end
machine.safe_call(:go, boat) # => another try with no effect but no exceptions
boat = machine.call(:undock, boat)
puts boat # => {name: "Paddleboat 1", docked: false}
boat = machine.call(:setup_paddles, boat)
puts boat # => {name: "Paddleboat 1", docked: false, paddles: 'on water'}
boat = machine.call(:go, boat)
puts boat # => {name: "Paddleboat 1", docked: false, paddles: 'on water', state: 'paddles'}
boat = machine.call(:stop, boat)
puts boat # => {name: "Paddleboat 1", docked: false, paddles: 'on water', state: 'stays'}

begin
  machine.call(:dock, boat)
rescue Machiner::WrongStateError
  puts "Can't dock with paddles on water"
end
boat = machine.call(:paddles_up, boat)
puts boat # => {name: "Paddleboat 1", docked: false, paddles: 'soft', state: 'stays'}
boat = machine.call(:dock, boat)
puts boat # => {name: "Paddleboat 1", docked: true}
puts "\n"

class SailboatMachine
  include SailboatStates
  include SailboatTransitions
end

# sailboat cruise is almost the same

class GalleyMachine
  include PaddleboatStates
  include SailboatStates
  include PaddleboatTransitions
  include SailboatTransitions

  state :ready do |g, m|
    ((m.state?(:soft_paddles, g) && m.state?(:sail_ready, g)) ||
     (m.state?(:paddles_ready, g) && m.state?(:sail_down, g))) &&
      (m.state?(:ready, g, key: :paddleboat) || m.state?(:ready, g, key: :sailboat))
  end

  state :ready_for_dock do |g, m|
    m.state?(:ready_for_dock, g, key: :paddleboat) &&
      m.state?(:ready_for_dock, g, key: :sailboat)
  end

  state :switchable do |g, m|
    m.state?(:stays, g) && m.state?(:on_water, g) && (m.state?(:paddles_ready, g) || m.state?(:sail_ready, g))
  end

  transition :switch_engine, %i[switchable paddles_ready] => :sail_ready do |g, m|
    g = m.call(:paddles_up, g)
    m.call(:set_sail, g)
  end

  transition :switch_engine, %i[switchable sail_ready] => :paddles_ready do |g, m|
    g = m.call(:take_away_sail, g)
    m.call(:setup_paddles, g)
  end

  transition :dock, ready_for_dock: :docked do |g, m|
    g = m.call(:dock, g, key: :base)
    g.delete(:paddles)
    g.delete(:sail)
    g
  end
end

# galley journey
puts "galley journey"
galley = { name: "Famous galley", docked: true }
puts galley
machine = GalleyMachine.new

galley = machine.call(:undock, galley)
puts galley # => {name: "Famous galley", docked: false}
# no wind, go on paddles
galley = machine.call(:setup_paddles, galley)
puts galley # => {name: "Famous galley", docked: false, paddles: "on water"}
galley = machine.call(:go, galley)
puts galley # => {name: "Famous galley", docked: false, paddles: "on water", state: "paddles"}
# it is windy now, lets change engine
begin
  machine.call(:switch_engine, galley)
rescue Machiner::WrongStateError
  puts "Can't switch engine in motion"
end
galley = machine.call(:stop, galley)
puts galley # => {name: "Famous galley", docked: false, paddles: "on water", state: "stays"}
galley = machine.call(:switch_engine, galley)
puts galley # => {name: "Famous galley", docked: false, paddles: "soft", sail: "ready", state: "stays"}
galley = machine.call(:go, galley)
puts galley # => {name: "Famous galley", docked: false, paddles: "soft", sail: "ready", state: "sails"}
galley = machine.call(:stop, galley)
puts galley
begin
  machine.call(:dock, galley)
rescue Machiner::WrongStateError
  puts "Can't dock while sail is ready or paddles are on water"
end
galley = machine.call(:take_away_sail, galley)
puts galley
galley = machine.call(:dock, galley)
puts galley
