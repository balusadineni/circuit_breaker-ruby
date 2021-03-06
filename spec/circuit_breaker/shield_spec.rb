require 'spec_helper'
require 'circuit_breaker-ruby'

CircuitBreaker.configure do |cb|
  cb.invocation_timeout = 1
  cb.retry_timeout = 1
  cb.failure_threshold = 1
end

describe CircuitBreaker::Shield do
  let(:circuit_breaker_shield) { CircuitBreaker::Shield.new }

  it 'goes to closed state' do
    circuit_breaker_shield.protect { sleep(0.1) }

    expect(circuit_breaker_shield.send :state).to be(CircuitBreaker::Shield::States::CLOSED)
  end

  it 'goes to open state' do
    no_of_tries = circuit_breaker_shield.failure_threshold * 2
    no_of_failures = no_of_tries * circuit_breaker_shield.config.failure_threshold_percentage
    no_of_success = no_of_tries - no_of_failures
    no_of_success.to_i.times { circuit_breaker_shield.protect { sleep(0.1) } }
    no_of_failures.to_i.times { circuit_breaker_shield.protect { sleep(2) } }

    expect(circuit_breaker_shield.send :state).to be(CircuitBreaker::Shield::States::OPEN)
  end

  it 'goes to half open state' do
    no_of_tries = circuit_breaker_shield.failure_threshold * 2
    no_of_failures = no_of_tries * circuit_breaker_shield.config.failure_threshold_percentage
    no_of_success = no_of_tries - no_of_failures
    no_of_success.to_i.times { circuit_breaker_shield.protect { sleep(0.1) } }
    no_of_failures.to_i.times { circuit_breaker_shield.protect { sleep(2) } }
    sleep(1)

    expect(circuit_breaker_shield.send :state).to be(CircuitBreaker::Shield::States::HALF_OPEN)
  end

  it 'raises CircuitBreaker::Shield::Open' do
    no_of_tries = circuit_breaker_shield.failure_threshold * 2
    no_of_failures = no_of_tries * circuit_breaker_shield.config.failure_threshold_percentage
    no_of_success = no_of_tries - no_of_failures
    no_of_success.to_i.times { circuit_breaker_shield.protect { sleep(0.1) } }

    expect { (no_of_failures.to_i + 1).times { circuit_breaker_shield.protect { sleep(2) } } }.to(
      raise_error(CircuitBreaker::Open)
    )
  end

  context '#protect' do
    it 'update invocation_timeout in config' do
      circuit_breaker_shield.protect(invocation_timeout: 20) {}

      expect(circuit_breaker_shield.invocation_timeout).to be(20)
    end

    it 'invokes callback on success' do
      callback = proc { 'Success' }
      circuit_breaker_shield = CircuitBreaker::Shield.new(callback: callback)
      expect(callback).to receive(:call).and_return('Success')

      circuit_breaker_shield.protect { { response: 'Dummy response' } }
    end
  end
end
