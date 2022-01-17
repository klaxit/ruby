# frozen_string_literal: true

RSpec.describe RuboCop::Cop::ActiveRecord::NoTransactionOnAddIndexMigration, :config do
  context "when it is a migration with add_index" do
    it "registers an offense when disable_ddl_transaction! not specified" do
      expect_offense(<<~RUBY)
        class Foo < ActiveRecord::Migration
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Migrations which add indexes should not be in transactions
          def change
            add_index :foo, :bar
          end
        end
      RUBY
    end
    it "accepts when disable_ddl_transaction! specified" do
      expect_no_offenses(<<~RUBY)
        class Foo < ActiveRecord::Migration
          disable_ddl_transaction!
          def change
            add_index :foo, :bar
          end
        end
      RUBY
    end
  end

  it "accepts when it is not a migration" do
    expect_no_offenses(<<~RUBY)
      class Foo < Bar
        def change
          add_index :foo, :bar
        end
      end
    RUBY
  end
  it "accepts when it is a migration without add_index" do
    expect_no_offenses(<<~RUBY)
      class Foo < ActiveRecord::Migration
        def change
          add_column :foo, :bar, :text
        end
      end
    RUBY
  end
end
