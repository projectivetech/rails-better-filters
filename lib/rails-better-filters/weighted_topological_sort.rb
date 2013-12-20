module RailsBetterFilters 
private
  module WeightedTopologicalSort
    # Input:
    # nodes = Hash of node name => priority.
    # edges = Hash of node name => list of children.
    # Output: 
    # List of node names.
    def self.sort(nodes, edges)
      # We use the algorithm of Kahn (1962) from 
      # http://en.wikipedia.org/w/index.php?title=Topological_sorting&oldid=586746444
      # and enhance it by sorting the set of nodes with no
      # incoming edges by their priority.

      # First convert to our own data structures.
      nodes = make_nodes(nodes)
      edges = make_edges(edges)

      # The list.
      l = []

      # Find all nodes with no incoming edges.
      s = nodes.select { |n| edges.none? { |e| e.to?(n) } }
      while !s.empty?
        # Here's the priority trick.
        s.sort!.reverse!

        # Get the one with the highest priority.
        current = s.shift
        l << current

        # Get all outgoing edges from current node and remove them from the graph.
        outgoing, edges = edges.partition { |e| e.from?(current) }

        # Find current's children.
        children_names = outgoing.map { |e| e.to }
        children = nodes.select { |n| children_names.include?(n.name) }

        # If child has no other incoming edges, we can add it to s.
        children.each do |n|
          if edges.none? { |e| e.to?(n) }
            s << n
          end
        end
      end

      # If there are still edges in the graph, there is at least one cycle.
      raise 'graph is not acyclic!' if !edges.empty?

      # Convert to names again.
      l.map { |n| n.name }
    end

  private

    def self.make_nodes(nodes)
      nodes.map { |name, priority| Node.new(name, priority) }
    end

    def self.make_edges(edges)
      edges.map { |from, to_list| to_list.map { |to| [from, to] }}.flatten(1).map { |a| Edge.new(a[0], a[1]) }
    end

    class Node
      include Comparable

      attr_reader :name, :priority
      
      def initialize(n, p)
        @name = n
        @priority = p
      end

      def <=>(other)
        priority <=> other.priority
      end
    end

    class Edge
      attr_reader :from, :to

      def initialize(from, to)
        @from = from
        @to = to
      end

      def to?(node)
        @to == node.name
      end

      def from?(node)
        @from == node.name
      end
    end
  end
end
