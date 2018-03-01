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

  context 'clang' do
    it 'correct verbatim string matches' do
      compiler = 'clang-800.0.42.1'

      stubbed_env.stub_command('type').outputs('/usr/bin/clang')
      stubbed_env.stub_command('cc::check_cc_path')
      stubbed_env.stub_command('cc::check_sys_cc')
      stubbed_env.stub_command('clang')
                 .outputs('Apple LLVM version 8.0.0 (clang-800.0.42.1)')

      out, err, status = stubbed_env.execute_function(
        file,
        "#{func} #{compiler}",
      )

      expect(status.exitstatus).to be 0
      expect(out).to eq('')
      expect(err).to eq('')
    end

    it 'verbatim sub-string matches' do
      compiler = 'clang-800.0.42'

      stubbed_env.stub_command('type').outputs('/usr/bin/clang')
      stubbed_env.stub_command('cc::check_cc_path')
      stubbed_env.stub_command('cc::check_sys_cc')
      stubbed_env.stub_command('clang')
                 .outputs('Apple LLVM version 8.0.0 (clang-800.0.42.1)')

      out, err, status = stubbed_env.execute_function(
        file,
        "#{func} #{compiler}",
      )

      expect(status.exitstatus).to be 0
      expect(out).to eq('')
      expect(err).to eq('')
    end

    it 'verbatim super-string does not match' do
      compiler = 'clang-800.0.42.1.123456789'

      stubbed_env.stub_command('type').outputs('/usr/bin/clang')
      stubbed_env.stub_command('cc::check_cc_path')
      stubbed_env.stub_command('cc::check_sys_cc')
      stubbed_env.stub_command('clang')
                 .outputs('Apple LLVM version 8.0.0 (clang-800.0.42.1)')

      out, err, status = stubbed_env.execute_function(
        file,
        "#{func} #{compiler}",
      )

      expect(status.exitstatus).to be 1
      expect(out).to eq('')
      expect(err).to match("expected #{compiler}")
    end

    it 'regex matches' do
      compiler = '^clang-800.0.42.1$'

      stubbed_env.stub_command('type').outputs('/usr/bin/clang')
      stubbed_env.stub_command('cc::check_cc_path')
      stubbed_env.stub_command('cc::check_sys_cc')
      stubbed_env.stub_command('clang')
                 .outputs('Apple LLVM version 8.0.0 (clang-800.0.42.1)')

      out, err, status = stubbed_env.execute_function(
        file,
        "#{func} #{compiler}",
      )

      expect(status.exitstatus).to be 0
      expect(out).to eq('')
      expect(err).to eq('')
    end

    it 'regex sub-string does not match' do
      compiler = '^clang-800.0.42$'

      stubbed_env.stub_command('type').outputs('/usr/bin/clang')
      stubbed_env.stub_command('cc::check_cc_path')
      stubbed_env.stub_command('cc::check_sys_cc')
      stubbed_env.stub_command('clang')
                 .outputs('Apple LLVM version 8.0.0 (clang-800.0.42.1)')

      out, err, status = stubbed_env.execute_function(
        file,
        "#{func} #{compiler}",
      )

      expect(status.exitstatus).to be 1
      expect(out).to eq('')
      expect(err).to match("expected #{Regexp.escape(compiler)}")
    end
  end # clang
end
