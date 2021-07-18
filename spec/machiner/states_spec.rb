# frozen_string_literal: true

require "spec_helper"

RSpec.describe Machiner::States do
  klasses = {
    base_class: %i[base_class base_class],
    class_with_included_module: %i[class_with_included_module describer_module],
    nested_class: %i[nested_class nested_class],
    nested_from_included_module_class: %i[nested_from_included_module_class describer_module]
  }

  klasses.each do |type, (klass, evaluator_name)|
    context type.to_s do
      let(:root_module) { Module.new { extend Machiner::States } }
      let(:describer_module) { rm = root_module; Module.new { include rm } }
      let(:base_class) { Class.new { extend Machiner::States } }
      let(:class_with_included_module) { dm = describer_module; Class.new { include dm } }
      let(:nested_class) { Class.new(base_class) }
      let(:nested_from_included_module_class) { Class.new(class_with_included_module) }
      let(:described_class) { send klass }
      let(:evaluator) { send evaluator_name }
      let(:machine) { described_class.new }

      describe "::state" do
        it "registers state on #{evaluator_name} state container" do
          allow(evaluator.state_container).to receive(:register)
          evaluator.send :state, :test, ->(_c) { true }
          expect(evaluator.state_container).to have_received(:register)
        end

        it "registers state on #{klass} state container" do
          allow(described_class.state_container).to receive(:register)
          described_class.send :state, :test2, ->(_c) { true }
          expect(described_class.state_container).to have_received(:register)
        end
      end

      describe "::meta" do
        it "adds configured meta to every new state configured on given container level" do
          allow(evaluator.state_container).to receive(:register)
          evaluator.send :meta, key: :test
          evaluator.send :state, :test, ->(_c) { true }
          expect(evaluator.state_container).to have_received(:register).with(anything, anything,
                                                                             hash_including(key: :test))
        end

        it "doesnt add meta to every new state configured on other container level" do
          skip "for cases when meta defined on described class" if evaluator == described_class
          allow(described_class.state_container).to receive(:register)
          evaluator.send :meta, key: :test
          described_class.send :state, :test, ->(_c) { true }
          expect(described_class.state_container).not_to have_received(:register).with(anything, anything,
                                                                                       hash_including(key: :test))
        end
      end

      describe "::state_names" do
        it "returns names from parent declarations" do
          evaluator.send :state, :test, ->(_c) { true }
          expect(described_class.state_names).to be_eql(["test"])
        end

        it "returns names from child declarations" do
          described_class.send :state, :test2, ->(_c) { true }
          expect(described_class.state_names).to be_eql(["test2"])
        end

        it "returns both parent and child state names" do
          evaluator.send :state, :test, ->(_c) { true }
          described_class.send :state, :test2, ->(_c) { true }
          expect(machine.state_names.sort).to be_eql(%w[test test2])
        end
      end

      describe "#state?" do
        it "returns true on corresponding state configured on parent" do
          evaluator.send :state, :test, ->(c) { c.key? :some_key }
          expect(machine).to be_state(:test, { some_key: 1 })
        end

        it "returns false on state configured on parent but call returns false" do
          evaluator.send :state, :test, ->(c) { c.key? :some_key }
          expect(machine).not_to be_state(:test, { some_key2: 1 })
        end

        it "returns true on corresponding state configured on child" do
          described_class.send :state, :test2, ->(c) { c.key? :some_key2 }
          expect(machine).to be_state(:test2, { some_key2: 2 })
        end

        it "returns false on state configured on child but call returns false" do
          described_class.send :state, :test2, ->(c) { c.key? :some_key2 }
          expect(machine).not_to be_state(:test2, { some_key: 1 })
        end

        it "returns true on state by meta key" do
          evaluator.send(:state, :test, ->(c) { c.key?(:some_key) }, key: :parent)
          described_class.send(:state, :test, ->(c) { c.key?(:some_key) && c.key?(:some_key2) })
          expect(machine).to be_state(:test, { some_key: 1 }, key: :parent)
        end
      end

      describe "#states" do
        it "returns list of states described on child and parent" do
          evaluator.send :state, :test, ->(c) { c.key? :some_key }
          described_class.send :state, :test2, ->(c) { c.key? :some_key2 }
          expect(machine.states({ some_key: 1, some_key2: 2 }).sort).to be_eql(%w[test test2].sort)
        end
      end
    end
  end
end
