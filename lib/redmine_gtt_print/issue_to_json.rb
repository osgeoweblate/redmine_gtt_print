module RedmineGttPrint

  # Transforms the given issue into JSON ready to be sent to the mapfish print
  # server.
  #
  class IssueToJson
    def initialize(issue, layout, other_attributes = {}, custom_fields = {}, attachments = [])
      @issue = issue
      @layout = layout
      @attachments = attachments
      @custom_fields = custom_fields
      @other_attributes = other_attributes
    end

    def self.call(*_)
      new(*_).call
    end

    def call
      # makes custom fields accessible by name
      @issue.visible_custom_field_values.each do |cfv|
        @custom_fields.store(cfv.custom_field.name, cfv)
      end

      # collects image attachment URL's
      @issue.attachments.each do |a|
        if a.image?
          # TODO: url construction doesn't look safe
          @attachments << "#{Setting.protocol}://#{Setting.host_name}/attachments/download/#{a.id}/#{a.filename}"
        end
      end

      json = {
        layout: @layout,
        attributes: self.class.attributes_hash(@issue, @other_attributes, @custom_fields, @attachments)
      }

      if data = @issue.geodata_for_print
        json[:attributes][:map] = self.class.map_data(data[:center], [data[:geojson]])
      end

      pp json

      json.to_json
    end

    # the following static helpers are used by IssuesToJson as well

    def self.attributes_hash(issue, other_attributes, custom_fields, attachments)
      {
        id: issue.id,
        subject: issue.subject,
        project_id: issue.project_id,
        project_name: (Project.find issue.project_id).name,
        tracker_id: issue.tracker_id,
        tracker_name: (Tracker.find issue.tracker_id).name,
        status_id: issue.status_id,
        status_name: (IssueStatus.find issue.status_id).name,
        priority_id: issue.priority_id,
        priority_name: (IssuePriority.find issue.priority_id).name,
        # category_id: issue.category_id,
        author_id: issue.author_id,
        author_name: (User.find issue.author_id).name,
        assigned_to_id: issue.assigned_to_id,
        assigned_to_name: issue.assigned_to_id ? (User.find issue.author_id).name : "WIP",
        description: issue.description,
        is_private: issue.is_private,
        start_date: issue.start_date,
        done_date: issue.closed_on,
        # due_date: issue.due_date,
        estimated_hours: issue.estimated_hours,
        created_on: issue.created_on,
        updated_on: issue.updated_on,
        last_notes: issue.last_notes ? issue.last_notes : "",

        # Custom text
        custom_text: other_attributes[:custom_text],

        # Custom fields fbased on names
        cf_通報者: custom_fields["通報者"] ? custom_fields["通報者"].value : "",
        cf_通報手段: custom_fields["通報手段"] ? custom_fields["通報手段"].value : "",
        cf_通報者電話番号: custom_fields["通報者電話番号"] ? custom_fields["通報者電話番号"].value : "",
        cf_通報者メールアドレス: custom_fields["通報者メールアドレス"] ? custom_fields["通報者メールアドレス"].value : "",
        cf_現地住所: custom_fields["現地住所"] ? custom_fields["現地住所"].value : "",

        # Image attachments (max. 4 iamges)
        image_url_1: attachments.at(0) ? attachments.at(0) : "",
        image_url_2: attachments.at(1) ? attachments.at(1) : "",
        image_url_3: attachments.at(2) ? attachments.at(2) : "",
        image_url_4: attachments.at(3) ? attachments.at(3) : "",

        # Experimental
        # issue: issue,
        # project: (Project.find issue.project_id),
        # tracker: (Tracker.find issue.tracker_id),
        # status: (IssueStatus.find issue.status_id),
        # priority: (IssuePriority.find issue.priority_id),
        # author: (User.find issue.author_id),
        # assigned_to: (User.find issue.assigned_to_id),

#         journals: issue.visible_journals_with_index.map{|j|
#           {
#             user: { login: j.user&.login, id: j.user&.id, name: j.user&.name },
#             notes: j.notes,
#             created_on: j.created_on,
#             details: j.visible_details.map{|d|
#               {
#                 property: d.property,
#                 name: d.prop_key,
#                 old_value: d.old_value,
#                 new_value: d.new_value
#               }
#             }
#           }
#         },
#         attachments: issue.attachments.map{|a|
#           {
#             id: a.id,
#             filename: a.filename,
#             filesize: a.filesize,
#             content_type: a.content_type,
#             description: a.description,
#             content_url: nil, # this is a bit more complex as we do not have access to URL generation methods here.
#           }
#         }
      }
    end

    def self.map_data(center, features)
      {
        center: center,
        rotation: 0,
        longitudeFirst: true,
        layers: [
          {
            geoJson: {
              features: features,
              type: "FeatureCollection",
            },
            style: {
              val1: "#FF4500",
              "*": {
                symbolizers: [{
                fillColor: "#FF0000",
                strokeWidth: 5,
                fillOpacity: 0,
                graphicName: "circle",
                rotation: "30",
                strokeDashstyle: "solid",
                strokeLinecap: "round",
                type: "point",
                graphicOpacity: 0.4,
                strokeColor: " ${val1}",
                pointRadius: 8,
                strokeOpacity: 1
              }]},
              version: "2"
            },
            type: "geojson"
          },
          {
            baseURL: "https://cyberjapandata.gsi.go.jp/xyz/std",
            imageExtension: "png",
            type: "osm"
          }
        ],
        scale: 25000,
        projection: "EPSG:3857",
        dpi: 144
      }
    end

  end
end
