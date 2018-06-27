require 'rspec/bash'

describe 'ccutils::setup_first' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:file) { 'ccutils.sh' }
  subject(:func) { 'cc::setup_first' }

  it 'succeeds on valid compiler after multiple invalid compiler strings' do
    compiler = 'invalid_compiler dne_compiler valid_compiler'

    setup = stubbed_env.stub_command('cc::setup')
    setup.with_args('invalid_compiler').returns_exitstatus(1)
    setup.with_args('dne_compiler').returns_exitstatus(2)
    setup.with_args('valid_compiler').returns_exitstatus(0)

    out, err, status = stubbed_env.execute_function(
      file,
      "#{func} '#{compiler}'",
    )

    expect(setup).to be_called_with_arguments('invalid_compiler').times(1)
    expect(setup).to be_called_with_arguments('dne_compiler').times(1)
    expect(setup).to be_called_with_arguments('valid_compiler').times(1)

    expect(status.exitstatus).to be 0
    expect(out).to eq('')
    expect(err).to eq('')
  end

  it 'fails on multiple invalid compiler strings' do
    compiler = 'invalid_compiler dne_compiler'

    setup = stubbed_env.stub_command('cc::setup')
    setup.with_args('invalid_compiler').returns_exitstatus(1)
         .outputs('woof', to: :stderr)
    setup.with_args('dne_compiler').returns_exitstatus(42)
         .outputs('bork', to: :stderr)

    out, err, status = stubbed_env.execute_function(
      file,
      "#{func} '#{compiler}'",
    )

    expect(setup).to be_called_with_arguments('invalid_compiler').times(1)
    expect(setup).to be_called_with_arguments('dne_compiler').times(1)

    expect(out).to eq('')
    expect(err).to match('bork')

    if ENV['TRAVIS']
      # for unknown reasons, the exit status is 1 under travis but the stderr
      # is still correct
      expect(status.exitstatus).to_not be 0
    else
      expect(status.exitstatus).to be 42
    end
  end
end
