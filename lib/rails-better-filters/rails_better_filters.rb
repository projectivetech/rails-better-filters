module RailsBetterFilters
  def self.included(base)
    base.extend(ClassMethods)
  end

  def dispatch_better_filters(action = nil)
    if !action
      if defined? params && params[:action]
        action = params[:action]
      else
        raise ArgumentError, 'no action given'
      end
    end

    self.class.better_filter_chain_each do |name, callback, only|
      if only.empty? || only.include?(action.to_sym)
        if callback.is_a?(Symbol) && self.respond_to?(callback, true)
          self.send(callback)
        elsif callback.is_a?(Proc)
          self.instance_eval(&callback)
        elsif callback.respond_to?(:call)
          callback.call
        else
          raise ArgumentError, "don't know how to call better_filter #{name} (Callback: #{callback.inspect})"
        end
      end
    end
  end

  module ClassMethods
    # Register a new bfilter, or overwrite (!) an
    # already register one. Set a callback function
    # (i.e. a symbol naming an instance method of the
    # resp. controller), callable or block.
    # If neither callback nor block are given, the name
    # of the filter is used as the name of the instance
    # method.
    def better_filter(name, callback = nil, &block)
      @bfilters ||= {}

      if callback
        @bfilters[name.to_sym] = callback
      elsif block_given?
        @bfilters[name.to_sym] = block
      else
        @bfilters[name.to_sym] = name
      end
    end

    # Set some options for a bfilter. Option hashes get
    # merged in the end, conflicting options will be resolved
    # based on the value of the :importance entry (the higher
    # the better).
    def better_filter_opts(name, opts = {})
      @bfilter_opts ||= {}
      @bfilter_opts[name.to_sym] ||= []
      @bfilter_opts[name.to_sym] << sanitize_opts(opts)
    end

    # Get the chain of bfilters for this class. Uses caching for
    # performance of subsequent calls.
    # Returns a list of hashes of :name => [:only_actions], e.g.
    # [{:bfilter1 => [:action1, :action2], :bfilter2 => [], ...}]
    def better_filter_chain
      if !@final_bfilter_chain
        # Make sure everything is in place.
        @bfilters     ||= {}
        @bfilter_opts ||= {}

        # Get advice from our forefathers.
        igo = inherited_bfilter_opts
        ig = inherited_bfilters

        # Do the math.
        @final_bfilter_opts = finalize_bfilter_opts(ig, igo)
        @final_bfilter_chain = finalize_bfilters(ig, @final_bfilter_opts)
      end

      @final_bfilter_chain
    end

    def better_filter_chain_each
      better_filter_chain.each do |bfilter|
        name = bfilter.keys.first
        data = bfilter.values.first
        yield name, data[:callback], data[:only]
      end
    end

  private

    # Finds all the bfilters referenced in all base classes of the
    # current class. For conflicting bfilters, the most recent one
    # (i.e. youngest in inheritance hierarchy) is chosen.
    def inherited_bfilters
      ancestors.reverse.inject({}) do |ig, ancestor|
        if ancestor.instance_variable_defined?(:@bfilters)
          ig.merge(ancestor.instance_variable_get(:@bfilters))
        else
          ig
        end
      end
    end

    # Finds all bfilter_opts hashes in ancestor classes and the
    # current class, storing them in an array.
    def inherited_bfilter_opts
      ancestors.inject({}) do |igo, ancestor|
        if ancestor.instance_variable_defined?(:@bfilter_opts)
          ancestor.instance_variable_get(:@bfilter_opts).each do |name, opts|
            igo[name] ||= []
            igo[name].concat(opts)
          end
        end
        igo
      end
    end

    # Consolidates an array of bfilter_opts hashes into
    # a single hash, ensures bfilter_opts hashes for every
    # known bfilter and discards hashes for unknown bfilters.
    def finalize_bfilter_opts(_bfilters, _bfilter_opts)
      result = {}
      _bfilters.keys.each do |name|
        if !_bfilter_opts[name] || _bfilter_opts[name].empty?
          # Default options if no option hash given.
          result[name] = sanitize_opts({})
        elsif _bfilter_opts[name].size == 1
          # Use the first option hash if only one was given.
          result[name] = _bfilter_opts[name].first
        else
          # Flatten multiple option hashs weighted by their :importance.
          result[name] = flatten_opts_list(_bfilter_opts[name])
        end 
        # Drop the now useless :importance field.
        result[name].delete(:importance)
      end
      result
    end

    # Finds a topological weighted ordering for the bfilters
    # known in this class and given the various :before, 
    # :after, :blocks, and :priority constraints.
    # Returns a list of hashes of bfilter names pointing to their
    # callbacks and :only constraints.
    def finalize_bfilters(_bfilters, _bfilter_opts)
      # Step 0: Drop unknown :before, :after, :block constraints
      #         and convert all :after constraints into :before.
      _bfilter_opts.each do |name, opts|
        [:before, :after, :blocks].each do |s|
          opts[s].select! { |g| _bfilters.keys.include?(g) }
        end

        while (g = opts[:after].shift)
          if !_bfilter_opts[g][:before].include?(name)
            _bfilter_opts[g][:before] << name
          end
        end
      end

      # Step 1: Make sure they're all unique now.
      _bfilter_opts.each do |_, opts|
        [:before, :blocks].each do |s|
          opts[s].uniq!
        end
      end

      # Step 2: Blocking! This is actually pretty tricky functionality. 
      #         For transitive :block constraints (e.g., bfilter :a
      #         blocks bfilter :b blocks bfilter :c), we want to block the 
      #         bfilters one after the other, i.e. in this case first block
      #         bfilter :b (as required by :a), but then *keep* bfilter :c, as
      #         it is now not blocked by :b anymore. The reasoning behind this
      #         is that :a most likely came last and knows about both :b and :c,
      #         so if :a wanted to block them both it would be sufficient to
      #         specify them both in the :block field. Need to find a real-world
      #         example for this.
      #         Anyway, the algorithm right now goes like this:
      #         Topologically sort the bfilters based on the :blocks DAG and their
      #         priority, execute all the blocks of the very first bfilter (that
      #         specifies blocks), repeat until no :blocks remain.

      # To speed things up a little, we first remove all nodes that do
      # not have any outgoing or incoming :blocks constraints.
      candidates = _bfilters.keys.select do |name| 
        !_bfilter_opts[name][:blocks].empty? ||
        _bfilter_opts.any? { |_, opts| opts[:blocks].include?(name) }
      end
      candidates_opts = _bfilter_opts.select { |name, _| candidates.include?(name) }

      victims = []
      loop do
        nodes = Hash[candidates.map { |name| [name, candidates_opts[:priority]] }]
        edges = Hash[candidates_opts.map { |name, opts| [name, opts[:blocks]] }]
        break if edges.empty?

        wts = WeightedTopologicalSort.sort(nodes, edges)
        executor = wts.shift

        # Do the blocks!
        victims.concat(candidates_opts[executor][:blocks])

        # Filter the candidates.
        candidates.delete(executor)
        candidates.reject! { |name| victims.include?(name) }
        candidates_opts.delete(executor)
        candidates_opts.reject! { |name, _| victims.include?(name) }
      end

      # Now the final shoot-the-bfilter-in-the-head.
      _bfilters     = _bfilters.reject { |name, _| victims.include?(name) }
      _bfilter_opts = _bfilter_opts.reject { |name, _| victims.include?(name) }

      # Step 3: Sorting! Compared to blocking, this is rather easy.
      #         Topological sort based on the :before values and the :priority.
      nodes = Hash[_bfilter_opts.map { |name, opts| [name, opts[:priority]] }]
      edges = Hash[_bfilter_opts.map { |name, opts| [name, opts[:before]] }]
      edges.select! { |_, to| !to.empty? }
      wts = WeightedTopologicalSort.sort(nodes, edges)

      # Step 4: Data shuffle.
      wts.map { |name| { name => {:callback => _bfilters[name], :only => _bfilter_opts[name][:only]} } }
    end

    # Default values for option hashes.
    def sanitize_opts(opts)
      opts = opts.dup
      opts[:importance] ||= 0
      opts[:priority] ||= 0
      [:before, :after, :blocks, :only].each do |k|
        if opts[k]
          opts[k] = [opts[k]] if !opts[k].is_a?(Array)
          opts[k].map! { |s| s.to_sym }
        else
          opts[k] = []
        end
      end
      opts
    end

    # Merges a list of option hashes ordered by their :importance, so that for conflicting
    # keys the value of the most important hash is chosen.
    def flatten_opts_list(opts_list)
      opts_list.sort_by { |opts| opts[:importance] }.inject({}) { |res, opts| res.merge(opts) }
    end
  end
end
