# Lexxy exports underline as <u> and strikethrough as <s>, which Action Text's
# sanitizer drops by default.
# Extend whatever is allowed so far (or the defaults), like Lexxy does, so the
# order the two hooks run in doesn't matter.
ActiveSupport.on_load(:action_text_content) do
  allowed_tags = Class.new.include(ActionText::ContentHelper).new.sanitizer_allowed_tags
  ActionText::ContentHelper.allowed_tags = allowed_tags | %w[ u s ]
end
