require 'rspec/bash'

describe 'cc::print_error' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:file) { 'ccutils.sh' }
  subject(:func) { 'cc::print_error' }

  it 'prints to stderr' do
    out, err, status = stubbed_env.execute_function(
      file,
      # this mysteriously breaks with single quotes...
      "#{func} 'lpisonfire!'",
    )

    expect(status.exitstatus).to be 0
    expect(out).to eq('')
    expect(err).to match('lpisonfire!')
  end

  it 'prints multiple params to stderr' do
    out, err, status = stubbed_env.execute_function(
      file,
      "#{func} 'lp' 'is' 'on' 'fire!'",
    )

    expect(status.exitstatus).to be 0
    expect(out).to eq('')
    expect(err).to match('lp is on fire!')
  end
end
