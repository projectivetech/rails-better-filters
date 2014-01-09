require 'spec_helper'

describe 'SomeTestToFindABug' do
  it 'works' do
    class Real2Controller
      include RailsBetterFilters

      def index
        @executed
      end

    private

      better_filter :filter_c
      def filter_c
        @executed ||= []
        @executed << :filter_c
      end

      better_filter :filter_a
      def filter_a
        @executed ||= []
        @executed << :filter_a
      end

      better_filter :filter_b
      def filter_b
        @executed ||= []
        @executed << :filter_b
      end


      better_filter_opts :filter_c, { :after => [:filter_b] }
      better_filter_opts :filter_a, { :before => [:filter_c] }
    end

    # Use it.
    r = Real2Controller.new
    r.dispatch_better_filters(:index)
    expect(r.index).to match_array([:filter_a, :filter_b, :filter_c])
  end
end
