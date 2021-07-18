# Machiner

## Usage

```ruby
module BoatStates
  extend Machiner::States
  state :on_water, -> b { b[:docked] != true } 
  state :in_dock, -> b { b[:docked] == true }
  state :stays, -> b { !b[:state] || b[:state] == 'stays' }
  state :ready_for_dock, -> b, m { m.state?(:on_water, b) }
end

module BoatTransitions
  extend Machiner::Transitions
  transition :dock, ready_for_dock: :in_dock do |b|
    b[:docked] = true && b.delete(:state)
  end

  transition :undock, in_dock: :on_water do |b|
    b[:docked] = false
  end
end

module PaddleboatStates
  include BoatStates
  meta key: :paddleboat
  state :ready, -> b, m { !m.state?(:docked, b) && m.state?(:stays, b) && m.state?(:paddles_ready, b) }
  state :paddles, -> b { b[:state] == 'paddles' }
  state :soft_paddles, -> b { !b[:paddles] || b[:paddles] == 'soft' }
  state :paddles_ready, -> b { b[:paddles] == 'on water' }
  state :ready_for_dock, -> b { m.state?(:on_water, b) && m.state?(:soft_paddles, b) }
end

module PaddleboatTransitions
  include BoatTransitions
  meta key: :paddleboat
  transition :go, ready: :paddles do |b|
    b[:state] = 'paddles'
  end

  transition :stop, paddles: :stays do |b|
    b[:state] = 'stays'
  end

  transition :setup_paddles, soft_paddles: :paddles_ready do |b|
    b[:paddles] = 'on water'
  end

  transition :paddles_up, paddles_ready: :soft_paddles do |b|
    b[:paddles] = 'soft'
  end

  transition :dock, ready_for_dock: :docked do |b, m|
    m.call(:dock, b, key: nil) && b.delete(:paddles)
  end
end

module SailboatStates
  include BoatStates
  meta key: :sailboat
  state :ready, -> b { !m.state?(:docked, b) && m.state?(:stays, b) && m.state?(:sail_ready, b) }
  state :sail_down, -> { b[:sail] == 'down' }
  state :sail_ready, -> b { b[:sail] == 'ready' }
  state :sails, -> b { b[:state] == 'sails' }
  state :ready_for_dock, -> b { m.state?(:on_water, b) && m.state?(:sail_down, b) }
end

module SailboatTransitions
  include BoatTransitions
  meta key: :sailboat
  transition :go, ready: :sails do |b|
    b[:state] = 'sails'
  end

  transition :stop, sails: :stays do |b|
    b[:state] = 'stays'
  end

  transition :set_sail, sail_down: :sail_ready do |b|
    b[:sail] = 'ready'
  end

  transition :take_away_sail, sail_ready: :sail_down do |b|
    b[:sail] = 'down'
  end

  transition :dock, ready_for_dock: :docked do |b, m|
    m.call(:dock, b, key: nil) && b.delete(:sail)
  end
end

class PaddleboatMachine
  include PaddleboatStates
  include PaddleboatTransitions
end

#paddleboat cruise
boat = {name: "Paddleboat 1", docked: true}
machine = PaddleboatMachine.new
machine.transition_names(boat) # => [:undock]
machine.call(:go, boat) # => Error
machine.safe_call(:go, boat) # => another try with no effect but no exceptions
machine.call(:undock, boat) # => {name: "Paddleboat 1", docked: false}
machine.call(:setup_paddles, boat) # =>  {name: "Paddleboat 1", docked: false, paddles: 'on water'}
machine.call(:go, boat) # => {name: "Paddleboat 1", docked: false, paddles: 'on water', state: 'paddles'}
machine.call(:stop, boat) # => {name: "Paddleboat 1", docked: false, paddles: 'on water', state: 'stays'}
machine.call(:dock) # => Error whoops, we forgot to make :paddle_up 
machine.call(:paddle_up, boat) # => {name: "Paddleboat 1", docked: false, paddles: 'soft', state: 'stays'}
machine.call(:dock, boat) # => {name: "Paddleboat 1", docked: true} 

class SailboatMachine
  include SailboatStates
  include SailboatTransitions
end

#sailboat cruise is almost the same

class GalleyMachine
  include PaddleboatStates
  include SailboatStates
  include PaddleboatTransitions
  include SailboatTransitions

  state :ready do |g, m|
    (
        (m.state?(:soft_paddles, g) && m.state?(:sail_ready, g)) 
        || # Запускаем гуся, работяги
        (m.state?(:paddles_ready, g) && m.state?(:sail_down, g))
    ) 
    && (m.state?(:ready, key: :paddleboat, g) || m.state?(:ready, key: :sailboat, g))
  end

  state :switchable do |g|
    m.state?(:stays, g) && m.state?(:on_water, g) && (m.state?(:paddles_ready, g) || m.state?(:sail_ready, g))
  end

  transition :switch_engine, [:switchable, :paddles_ready] => :sail_ready do |g, m|
    m.call(:paddles_up, g)
    m.call(:set_sail, g)
  end

  transition :switch_engine, [:switchable, :sail_ready] => :paddles_ready do |g|
    m.call(:take_away_sail, g)
    m.call(:setup_paddles, g)
  end
end

# galley journey
galley = {name: "Famous galley", docked: true}
machine = GalleyMachine.new

machine.call(:undock, galley) # => {name: "Famous galley", docked: false}
# no wind, go on paddles
machine.call(:setup_paddles, galley) # => {name: "Famous galley", docked: false, paddles: "on water"}
machine.call(:go, galley) # => {name: "Famous galley", docked: false, paddles: "on water", state: "paddles"}
# it is windy now, lets change engine
machine.call(:switch_engine, galley) # => Error, we should stay to switch engine
machine.call(:stop, galley) # => {name: "Famous galley", docked: false, paddles: "on water", state: "stays"}
machine.call(:switch_engine, galley) # => {name: "Famous galley", docked: false, paddles: "soft", sail: "ready", state: "stays"}
machine.call(:go, galley) # => {name: "Famous galley", docked: false, paddles: "soft", sail: "ready", state: "sails"}
machine.call(:stop, galley)
machine.call(:dock, galley)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/machiner. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/machiner/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Machiner project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/machiner/blob/master/CODE_OF_CONDUCT.md).
