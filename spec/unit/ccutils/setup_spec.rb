require 'rspec/bash'

describe 'ccutils::setup' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:file) { 'ccutils.sh' }
  subject(:func) { 'cc::setup' }

  it 'fails on unsupported compiler' do
    out, err, status = stubbed_env.execute_function(
      file,
      "#{func} magic-cc",
    )

    expect(status.exitstatus).to be 1
    expect(out).to eq('')
    expect(err).to match('lp is on fire!')
  end
end
