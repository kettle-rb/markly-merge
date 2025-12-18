# frozen_string_literal: true

module Markly
  module Merge
    # Represents a frozen block of Markdown content that should be preserved during merges.
    #
    # Inherits from Markdown::Merge::FreezeNode which provides the generic
    # freeze block handling.
    #
    # Freeze blocks are marked with HTML comments:
    #   <!-- markly-merge:freeze -->
    #   ... frozen content ...
    #   <!-- markly-merge:unfreeze -->
    #
    # @example Basic freeze block
    #   <!-- markly-merge:freeze -->
    #   ## Custom Section
    #   This content will not be modified by merge operations.
    #   <!-- markly-merge:unfreeze -->
    #
    # @example Freeze block with reason
    #   <!-- markly-merge:freeze Manual TOC -->
    #   ## Table of Contents
    #   - [Introduction](#introduction)
    #   - [Usage](#usage)
    #   <!-- markly-merge:unfreeze -->
    #
    # @see Markdown::Merge::FreezeNode
    class FreezeNode < Markdown::Merge::FreezeNode
    end
  end
end
