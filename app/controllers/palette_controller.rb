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
    @notes = search(Current.user.notes.includes(:notebook, :folder), @query)
  end

  private

    # A blank/whitespace-only query is the palette's normal resting
    # state: the 10 most recently viewed notes, most recent first.
    def search(scope, query)
      # reorder, not order — see the identical comment in
      # HomeController#index, which computes this same default state.
      return scope.reorder(last_viewed_at: :desc).limit(10) if query.blank?

      like = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      # Capped at 50 candidates before the Ruby-side sort — this app's
      # audience is too small for that to matter, and it keeps the
      # exact-prefix-first ranking simple without raw SQL.
      candidates = scope.where("title LIKE ? ESCAPE '\\'", like).limit(50).to_a

      prefix_matches, other_matches = candidates.partition { |note| note.title.downcase.start_with?(query.downcase) }
      by_recency = ->(note) { note.last_viewed_at || Time.at(0) }

      (prefix_matches.sort_by(&by_recency).reverse + other_matches.sort_by(&by_recency).reverse).first(10)
    end
end
