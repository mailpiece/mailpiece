module PaginationHelper
  # How long the calendar's top must stay in view before earlier weeks load over it: time to reach the site's menu.
  CALENDAR_PAGINATION_DELAY = 5.seconds

  def pagination_frame_tag(namespace, page, data: {}, **attributes, &)
    turbo_frame_tag pagination_frame_id_for(namespace, page.number), target: "_top", data: data, role: "presentation", **attributes, &
  end

  def link_to_next_page(namespace, page, label: default_pagination_label, data: {}, **attributes)
    if more_pages_after?(page) && !params[:previous]
      pagination_link(namespace, page.number + 1, label: label, data: data, **attributes)
    end
  end

  # The query only ever goes back into the query string. Handed to url_for as
  # options, its keys could choose the link's route, path segments, host or script
  # name. The route comes from the request's own path parameters, which url_for recalls.
  def pagination_link(namespace, page_number, label: default_pagination_label, url_params: {}, data: {}, **attributes)
    link_to label, url_for(params: request.query_parameters.merge(page: page_number, **url_params)),
      "aria-label": t("load_page", number: page_number),
      id: "#{namespace}-pagination-link-#{page_number}",
      class: class_names(attributes.delete(:class), "pagination-link", "pagination-link--active-when-observed"),
      data: {
        frame: pagination_frame_id_for(namespace, page_number),
        pagination_target: "paginationLink",
        **data
      },
      **attributes
  end

  def more_pages_after?(page)
    page.before_last?
  end

  def pagination_frame_id_for(namespace, page_number)
    "#{namespace}-pagination-contents-#{page_number}"
  end

  def with_automatic_pagination(name, page, **properties)
    pagination_list name, **properties do
      concat(pagination_frame_tag(name, page) do
        yield
        concat link_to_next_page(name, page)
      end)
    end
  end

  def calendar_frame_tag(calendar, &)
    turbo_frame_tag calendar_frame_id_for(calendar.from), target: "_top", role: "presentation", &
  end

  def calendar_frame_id_for(from)
    "calendar-contents-#{from.iso8601}"
  end

  def calendar_pagination_link(from, delayed: false)
    link_to t("load_more"), url_for(date: from.iso8601),
      class: "day-timeline-pagination-link",
      data: { frame: calendar_frame_id_for(from), pagination_target: "paginationLink", delay: (CALENDAR_PAGINATION_DELAY.in_milliseconds.to_i if delayed) }
  end

  # An agenda's windows are short, so its links are pressed: loaded as they come into view, each would bring the next.
  def calendar_more_link(label, from)
    link_to label, url_for(date: from.iso8601),
      class: "btn calendar__more",
      data: { frame: calendar_frame_id_for(from), pagination_target: "paginationLink", action: "pagination#loadPage:prevent" }
  end

  private
    def pagination_list(name, tag_element: :div, **properties, &block)
      classes = properties.delete(:class)
      properties[:id] ||= "#{name}-pagination-list"
      tag.public_send tag_element,
        class: token_list(name, "display-contents", classes),
        data: { controller: "pagination", pagination_paginate_on_intersection_value: true },
        **properties,
        &block
    end

    def default_pagination_label
      t("load_more")
    end
end
