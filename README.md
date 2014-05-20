# RailsBetterFilters

## Motivation

We found the default `before_filter`s of Rails to be too unflexible for our needs. Especially, we needed to be able to specify filter orders or dependency chains. Order may be specified using the `after` or `before` options to the `better_filter_opts` method. Better filters are inherited and may be used in combination with regular Rails filters.

## Usage

### Setup

In Gemfile:

```ruby
gem 'rails-better-filters'
```

In your base controller class:

```ruby
class ApplicationController < ActionController::Base
  include RailsBetterFilters
  before_filter :dispatch_better_filters
end
```

### Defining filters

Example:

```ruby
class SomeController < ApplicationController
  def filter_a
  end

  def filter_b_with_different_name
  end

  better_filter :filter_a
  better_filter :filter_b, :filter_b_with_different_name
  better_filter(:filter_c) do
    # Blocks are also ok.
  end

  better_filter :filter_d
  better_filter_opts :filter_d, { :only => [:some_action], :after => [:filter_c], :before => [:filter_a] }
end
```

Take a look at the generated topological sort:

```ruby
SomeController.better_filter_chain.map(&:keys).map(&:first).join(', ')
# => filter_c, filter_d, filter_a, filter_b
```

## License

RailsBetterFilters is licensed under the MIT-License. See [LICENSE](LICENSE) for details.
