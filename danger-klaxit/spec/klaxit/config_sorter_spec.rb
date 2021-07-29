# frozen_string_literal: true

require_relative "../spec_helper"
require_relative "../../lib/klaxit/config_sorter"

describe Klaxit::ConfigSorter do
  it "works with empty new lines" do
    expect(
      described_class
        .new("#{__dir__}/../support/fixtures/config_sorter/empty_new_line.yml")
        .sorted_file
    ).to eq(<<~YML)
      DEFAULTS:
        a_private_key: |
            foo

            bar
        log_level: "please show errors"

      playground:
        log_level: all
    YML
  end
end
