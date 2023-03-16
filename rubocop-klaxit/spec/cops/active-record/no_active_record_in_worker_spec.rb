# frozen_string_literal: true

RSpec.describe RuboCop::Cop::ActiveRecord::NoActiveRecordInWorker, :config do
  describe "when we call call_async on a service" do
    context "when the service has an instance of an ActiveRecord object" do
      before do
        allow(cop).to receive(:is_service_blacklisted?)
                        .with("ZendeskCreateTicketBad")
                        .and_return(true)
      end
      it "registers an offense" do
        expect_offense(<<~RUBY)
          ZendeskCreateTicketBad.call_async(mate)
        RUBY
      end
    end

    context "when the service uses identifiers" do
      before do
          allow(cop).to receive(:is_service_blacklisted?)
                          .with("ZendeskCreateTicketBad")
                          .and_return(true)
      end
      it "does not register an offense" do
        expect_no_offenses(<<~RUBY)
          ZendeskCreateTicketGood.call_async(123)
        RUBY
      end
    end
  end
end
