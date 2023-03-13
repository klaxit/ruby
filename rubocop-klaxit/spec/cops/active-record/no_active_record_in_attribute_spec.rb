# frozen_string_literal: true

RSpec.describe RuboCop::Cop::ActiveRecord::NoActiveRecordInAttribute, :config do
  context "when we call call_async" do
    it "registers an offense when the service has an attribute that is an instance of an ActiveRecord object" do
      expect_no_offenses(<<~RUBY)
        class ZendeskCreateTicketBad < Service
          attribute :mate, Types.Instance(Mate)
        end
      RUBY
    end

    # it "does not register an offense when the service uses identifiers" do
    #   expect_no_offenses(<<~RUBY)
    #     class ZendeskCreateTicketGood < Service
    #       attribute :mate_id,  Types::Strict::Integer
    #     end
    #   RUBY
    # end
  end
end
