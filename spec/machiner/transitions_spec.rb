# frozen_string_literal: true

require "spec_helper"

RSpec.describe Machiner::Transitions do
  klasses = {
    base_class: %i[base_class base_class],
    class_with_included_module: %i[class_with_included_module describer_module],
    nested_class: %i[nested_class nested_class],
    nested_from_included_module_class: %i[nested_from_included_module_class describer_module]
  }

  klasses.each do |type, (klass, evaluator_name)|
    context type.to_s do
      let(:describer_module) { Module.new { extend Machiner::Transitions } }
      let(:base_class) { Class.new { extend Machiner::Transitions } }
      let(:class_with_included_module) { dm = describer_module; Class.new { include dm } }
      let(:nested_class) { Class.new(base_class) }
      let(:nested_from_included_module_class) { Class.new(class_with_included_module) }
      let(:described_class) { c = send(klass); c.extend(Machiner::States); c }
      let(:evaluator) { send evaluator_name }
      let(:machine) { described_class.new }

      describe "::transition" do
        it "registers transition on #{evaluator_name} transition container" do
          allow(evaluator.transition_container).to receive(:register)
          evaluator.send :transition, :test, a: :b
          expect(evaluator.transition_container).to have_received(:register)
        end

        it "registers tranition on #{klass} transition container" do
          allow(described_class.transition_container).to receive(:register)
          described_class.send :transition, :test, a: :b
          expect(described_class.transition_container).to have_received(:register)
        end
      end

      describe "::transition_names" do
        it "returns names from parent declarations" do
          evaluator.send :transition, :test, a: :b
          expect(described_class.transition_names).to be_eql(["test"])
        end

        it "returns names from child declarations" do
          described_class.send :transition, :test2, a: :b
          expect(described_class.transition_names).to be_eql(["test2"])
        end

        it "returns both parent and child state names" do
          evaluator.send :transition, :test, a: :b
          described_class.send :transition, :test2, a: :b
          expect(machine.transition_names.sort).to be_eql(%w[test test2])
        end
      end

      describe "#transition?" do
        it "returns true on corresponding transition configured on parent" do
          evaluator.extend Machiner::States
          evaluator.send :state, :a, ->(c) { c.key? :some_key }
          evaluator.send :transition, :test, a: :b
          expect(machine).to be_transition(:test, { some_key: 1 })
        end

        it "returns false on transition configured on parent but call returns false" do
          evaluator.extend Machiner::States
          evaluator.send :state, :a, ->(c) { c.key? :some_key }
          evaluator.send :transition, :test, a: :b
          expect(machine).not_to be_transition(:test, { some_key2: 1 })
        end

        it "returns true on corresponding transition configured on child" do
          evaluator.extend Machiner::States
          evaluator.send :state, :b, ->(c) { c.key? :some_key2 }
          described_class.send :transition, :test2, b: :a
          expect(machine).to be_transition(:test2, { some_key2: 2 })
        end

        it "returns false on transition configured on child but call returns false" do
          evaluator.extend Machiner::States
          evaluator.send :state, :b, ->(c) { c.key? :some_key2 }
          described_class.send :transition, :test2, b: :a
          expect(machine).not_to be_transition(:test2, { some_key: 1 })
        end

        it "returns false on transition without meta key" do
          evaluator.extend Machiner::States
          evaluator.send :state, :a, ->(c) { c.key? :some_key2 }
          described_class.send :transition, :test2, a: :b
          expect(machine).not_to be_transition(:test2, { some_key2: 1 }, key: :some)
        end

        it "returns true on transition with meta key when meta set on state and transition" do
          evaluator.extend Machiner::States
          evaluator.send :state, :a, ->(c) { c.key? :some_key2 }, key: :some
          described_class.send :transition, :test2, { a: :b }, key: :some
          expect(machine).to be_transition(:test2, { some_key2: 1 }, key: :some)
        end
      end

      describe "#call" do
        it "raises exception if no transition with given name found" do
          expect { machine.call(:test, { some: :test_object }) }.to raise_error(Machiner::WrongTransitionError)
        end

        it "raises exception if transition found but no corresponding state found" do
          described_class.send :transition, :test, a: :b
          expect { machine.call(:test, { some: :test_object }) }.to raise_error(Machiner::WrongStateError)
        end

        it "calls block configured for transition" do
          described_class.extend Machiner::States
          described_class.send(:state, :a, ->(c) { c[:some] == :test_object })
          described_class.send(:transition, :test, a: :b) { |i| i[:some] = :hello_world; i }
          expect(machine.call(:test, { some: :test_object })).to be_eql({ some: :hello_world })
        end
      end

      describe "#safe_call" do
        it "doesnt raise exception if no transition with given name found" do
          expect { machine.safe_call(:test, { some: :test_object }) }.not_to raise_error
        end

        it "doesnt raise exception if transition found but no corresponding state found" do
          described_class.send :transition, :test, a: :b
          expect { machine.safe_call(:test, { some: :test_object }) }.not_to raise_error
        end

        it "calls block configured for transition" do
          described_class.extend Machiner::States
          described_class.send(:state, :a, ->(c) { c[:some] == :test_object })
          described_class.send(:transition, :test, a: :b) { |i| i[:some] = :hello_world; i }
          expect(machine.safe_call(:test, { some: :test_object })).to be_eql({ some: :hello_world })
        end
      end

      describe "#transitions" do
        it "returns list of available transitions described on child and parent" do
          evaluator.extend Machiner::States
          evaluator.send :state, :a, ->(c) { c.key? :some_key }
          described_class.send :state, :b, ->(c) { c.key? :some_key2 }
          evaluator.send :state, :c, ->(c) { c.key? :some_key3 }
          evaluator.send :transition, :switch, a: :b
          described_class.send :transition, :switch, b: :c
          expect(machine.transitions({ some_key: 1,
                                       some_key2: 2 })).to include(["switch", { from: :a, to: :b }],
                                                                   ["switch", { from: :b, to: :c }])
        end
      end
    end
  end
end
