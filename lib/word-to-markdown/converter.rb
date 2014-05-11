class WordToMarkdown
  class Converter

    attr_reader :document

    HEADING_DEPTH = 6 # Number of headings to guess, e.g., h6
    HEADING_STEP = 100/HEADING_DEPTH
    MIN_HEADING_SIZE = 20
    UNICODE_BULLETS = ["○", "●", "", "o"]

    def initialize(document)
      @document = document
    end

    def convert!
      semanticize_font_styles!
      semanticize_headings!
      remove_paragraphs_from_tables!
      remove_paragraphs_from_list_items!
      remove_unicode_bullets_from_list_items!
      remove_numbering_from_list_items!
    end

    # Returns an array of Nokogiri nodes that are implicit headings
    def implicit_headings
      @implicit_headings ||= begin
        headings = []
        @document.tree.css("[style]").each do |element|
          headings.push element unless element.font_size.nil? || element.font_size < MIN_HEADING_SIZE
        end
        headings
      end
    end

    # Returns an array of font-sizes for implicit headings in the document
    def font_sizes
      @font_sizes ||= begin
        sizes = []
        @document.tree.css("[style]").each do |element|
          sizes.push element.font_size.round(-1) unless element.font_size.nil?
        end
        sizes.uniq.sort
      end
    end

    # Given a Nokogiri node, guess what heading it represents, if any
    #
    # node - the nokigiri node
    #
    # retuns the heading tag (e.g., H1), or nil
    def guess_heading(node)
      return nil if node.font_size == nil
      [*1...HEADING_DEPTH].each do |heading|
        return "h#{heading}" if node.font_size >= h(heading)
      end
      nil
    end

    # Minimum font size required for a given heading
    # e.g., H(2) would represent the minimum font size of an implicit h2
    #
    # n - the heading number, e.g., 1, 2
    #
    # returns the minimum font size as an integer
    def h(n)
      font_sizes.percentile ((HEADING_DEPTH-1)-n) * HEADING_STEP
    end

    # Returns an array of all indented values
    def indents
      @indents ||= @document.tree.css("li").map{ |el| el.indent }.uniq.sort
    end

    # Determine the indent level given an indent value
    #
    # level - the true indent, e.g., 2.5 (from 2.5em)
    #
    # Returns an integer representing the indent level
    def indent(level)
      indents.find_index level
    end

    def semanticize_font_styles!
      @document.tree.css("span").each do |node|
        if node.bold?
          node.node_name = "strong"
        elsif node.italic?
          node.node_name = "em"
        end
      end
    end

    def remove_paragraphs_from_tables!
      @document.tree.search("td p").each { |node| node.node_name = "span" }
    end

    def remove_paragraphs_from_list_items!
      @document.tree.search("li p").each { |node| node.node_name = "span" }
    end

    def remove_unicode_bullets_from_list_items!
      @document.tree.search("li span").each do |span|
        span.content = span.content[1..-2] if UNICODE_BULLETS.include? span.content[0]
      end
    end

    def remove_numbering_from_list_items!
      @document.tree.search("li span").each do |span|
        span.content = span.content.gsub /^[a-zA-Z0-9]+\./m, ""
      end
    end

    # Try to guess heading where implicit bassed on font size
    def semanticize_headings!
      implicit_headings.each do |element|
        heading = guess_heading element
        element.node_name = heading unless heading.nil?
      end
    end

  end
end