class PaletteController < ApplicationController
  # Renders into the Ctrl+P command palette's own turbo-frame for the
  # authenticated app UI — HTML, not the "public JSON API" this project
  # rules out, and it requires the same session as everything else here.
  layout false

  def show
    @query = params[:q].to_s.strip
    # Always scoped through Current.user.notes, never a bare Note.where —
    # see coding-style.md and test/controllers/palette_privacy_test.rb,
    # which locks this in.
    @notes = Note.search_ranked(Current.user.notes.includes(:notebook, :folder), @query)
  end
end
