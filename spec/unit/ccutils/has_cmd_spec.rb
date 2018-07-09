# frozen_string_literal: true

require 'rspec/bash'

describe 'cc::has_cmd' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:file) { 'ccutils.sh' }
  subject(:func) { 'cc::has_cmd' }

  context 'parameters' do
    context '$1/command' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          file,
          func,
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match(/command is required/)
      end

      context 'bogus command' do
        it 'fails with error message' do
          cmd = 'batman'
          # rspec-bash 0.3.0 does not allow `command` to be stubbed as a special
          # case ;(
          out, err, status = stubbed_env.execute_function(
            file,
            "#{func} #{cmd}",
          )

          expect(status.exitstatus).to be 1
          expect(out).to eq('')
          expect(err).to match("command #{cmd} appears to be missing from PATH")
        end
      end

      context 'valid command' do
        it 'prints command path`' do
          cmd = 'cd'
          # rspec-bash 0.3.0 does not allow `command` to be stubbed as a special
          # case ;(
          out, err, status = stubbed_env.execute_function(
            file,
            "#{func} #{cmd}",
          )

          expect(status.exitstatus).to be 0
          expect(out).to eq("cd\n")
          expect(err).to eq('')
        end
      end
    end
  end
end
