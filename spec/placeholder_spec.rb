require 'spec_helper'

describe 'SimpleExampleUntilRealSpecsAreFinished' do
  it 'works' do
    class RealController
      include RailsBetterFilters

      def index
        @executed
      end

      def show
        @executed
      end

    private

      better_filter :load_filter
      def load_filter
        @executed ||= []
        @executed << :load_filter
      end

      better_filter :authorize_me do
        @executed ||= []
        @executed << :authorize_me
      end

      better_filter_opts :authorize_me, { :before => [:load_filter], :only => [:show] }
    end

    # Use it.
    r = RealController.new
    r.dispatch_better_filters(:index)
    expect(r.index).to match_array([:load_filter])

    r = RealController.new
    r.dispatch_better_filters(:show)
    expect(r.index).to match_array([:authorize_me, :load_filter])
  end
end
