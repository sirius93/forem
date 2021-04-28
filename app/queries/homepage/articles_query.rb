module Homepage
  class ArticlesQuery
    ATTRIBUTES = %i[
      cached_tag_list
      comments_count
      crossposted_at
      id
      organization_id
      path
      public_reactions_count
      published_at
      reading_time
      title
      user_id
      video_duration_in_seconds
      video_thumbnail_url
    ].freeze
    DEFAULT_PER_PAGE = 60
    MAX_PER_PAGE = 100
    SORT_PARAMS = %i[hotness_score public_reactions_count].freeze

    def self.call(...)
      new(...).call
    end

    # TODO: [@rhymes] change frontend to start from page 1
    def initialize(
      approved: nil,
      published_at: nil,
      user_id: nil,
      organization_id: nil,
      tags: [],
      sort_by: nil,
      sort_direction: nil,
      page: 0,
      per_page: DEFAULT_PER_PAGE
    )
      @relation = Article.published.select(*ATTRIBUTES)

      @approved = approved
      @published_at = published_at
      @user_id = user_id
      @organization_id = organization_id
      @tags = tags.presence || []

      @sort_by = sort_by
      @sort_direction = sort_direction

      @page = page.to_i + 1
      @per_page = [(per_page || DEFAULT_PER_PAGE).to_i, MAX_PER_PAGE].min
    end

    def call
      filter.merge(sort).merge(paginate)
    end

    private

    attr_reader :relation, :approved, :published_at, :user_id, :organization_id, :tags, :sort_by, :sort_direction,
                :page, :per_page

    def filter
      @relation = @relation.where(approved: approved) unless approved.nil?
      @relation = @relation.where(published_at: published_at) if published_at.present?
      @relation = @relation.where(user_id: user_id) if user_id.present?
      @relation = @relation.where(organization_id: organization_id) if organization_id.present?

      # as tags are in `OR` mode we can't use ActiveRecord's `.or()` because it
      # would put all the previous filters in `OR` mode with tags, but what we need
      # is to only consider tags as a `OR` sub-condition
      if tags.present?
        # `~` is the regexp operator, the `\m` modifier signifies the "beginning of word",
        # and the `\M` modifier signifies the "end of word".
        # see https://www.postgresql.org/docs/11/functions-matching.html#FUNCTIONS-POSIX-REGEXP
        # for additional info
        conditions = tags.map { |tag| relation.sanitize_sql_array(["cached_tag_list ~ ?", "\\m#{tag}\\M"]) }
        @relation = @relation.where(conditions.join(" OR "))
      end

      relation
    end

    def sort
      return relation unless SORT_PARAMS.include?(sort_by&.to_sym)

      relation.order(sort_by => sort_direction)
    end

    def paginate
      relation.page(page).per(per_page)
    end
  end
end
