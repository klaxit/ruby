# frozen_string_literal: true

RSpec.describe RuboCop::Cop::ActiveRecord::NoActiveRecordInWorker, :config do
  describe "when we call call_async on a service" do
    context "when the service has an instance of an ActiveRecord object" do
      before do

      end
      it "registers an offense" do
        expect(cop).to receive(:is_service_blacklisted?)
                         .with(:ZendeskCreateTicketBad)
                         .and_return(true)
        expect_offense(<<~RUBY)
          ZendeskCreateTicketBad.call_async(mate)
        RUBY
      end
    end

    context "when the service uses identifiers" do
      before do

      end
      it "does not register an offense" do
        expect(cop).to receive(:is_service_blacklisted?)
                         .with(:ZendeskCreateTicketGood)
                         .and_return(false)
        expect_no_offenses(<<~RUBY)
          ZendeskCreateTicketGood.call_async(123)
        RUBY
      end
    end
  end
end
