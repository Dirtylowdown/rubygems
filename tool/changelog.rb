end
    end
        end
        delete
        stop
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        

    entries = prepare_entries(included_pull_requests, extra_entry)

    group_by_labels(entries).each do |label, label_entries|
      category = changelog_label_mapping[label]

      lines << category
      lines << ""

      label_entries.reverse_each do |label_entry|
        lines << format_entry_for(label_entry)
      end

      lines << ""
    end

    lines
  end

  def relevant_label_for(pull)
    relevant_labels = pull.labels.map(&:name) & changelog_labels
    return unless relevant_labels.any?

    raise "#{pull.html_url} has multiple labels that map to changelog sections" unless relevant_labels.size == 1

    relevant_labels.first
  end

  private

  attr_reader :version

  def format_header
    new_header = header_template.gsub(/%new_version/, version.to_s)

    if header_template.include?("%release_date")
      new_header = new_header.gsub(/%release_date/, Time.now.strftime(release_date_format))
    end

    new_header
  end

  def format_entry_for(entry)
    new_entry = entry.template.gsub(/%title/, entry.title)
    pull = entry.pull_request

    if pull
      new_entry = new_entry.
        gsub(/%pull_request_number/, pull.number.to_s).
        gsub(/%pull_request_url/, pull.html_url).
        gsub(/%pull_request_author/, pull.user.name || pull.user.login)
    end

    new_entry = wrap(new_entry, entry_wrapping, 2) if entry_wrapping

    new_entry
  end

  def wrap(text, length, indent)
    result = []
    work = text.dup

    while work.length > length
      if work =~ /^(.{0,#{length}})[ \n]/o
        result << $1
        work.slice!(0, $&.length)
      else
        result << work.slice!(0, length)
      end
    end

    result << work unless work.empty?
    result = result.reduce(String.new) do |acc, elem|
      acc << "\n" << " " * indent unless acc.empty?
      acc << elem
    end
    result
  end

  def prepare_entries(pulls, extra_entry)
    entries = pulls.map do |pull|
      ChangelogEntry.new(
        pull.title.strip.delete_suffix(".").tap {|s| s[0] = s[0].upcase },
        entry_template,
        labels: pull.labels,
        pull_request: pull
      )
    end

    entries << ChangelogEntry.new(
      extra_entry,
      extra_entry_template,
      labels: [Struct.new(:name).new(extra_entry_label)]
    ) if extra_entry

    entries
  end

  def group_by_labels(pulls)
    grouped_pulls = pulls.sort_by(&:updated_at).group_by do |pull|
      relevant_label_for(pull)
    end

    grouped_pulls.delete_if {|k, _v| changelog_label_mapping[k].nil? }

    grouped_pulls.sort do |a, b|
      changelog_labels.index(a[0]) <=> changelog_labels.index(b[0])
    end.to_h
  end

  def relevant_changelog_label_mapping
    if @level == :patch
      changelog_label_mapping.slice(*patch_level_labels)
    else
      changelog_label_mapping
    end
  end

  def changelog_labels
    relevant_changelog_label_mapping.keys
  end

  def change_types
    relevant_changelog_label_mapping.values
  end

  def released_notes_until(version)
    lines.drop_while {|line| !line.start_with?(release_section_token) || !line.include?(version) }
  end

  def lines
    @lines ||= content.split("\n")
  end

  def content
    File.read(@file)
  end

  def release_section_token
    header_template.match(/^(\S+\s+)/)[1]
  end

  def header_template
    @config["header_template"]
  end

  def entry_template
    @config["entry_template"]
  end

  def extra_entry_template
    @config["extra_entry"]["template"]
  end

  def extra_entry_label
    @config["extra_entry"]["label"]
  end

  def release_date_format
    @config["release_date_format"]
  end

  def entry_wrapping
    @config["entry_wrapping"]
  end

  def changelog_label_mapping
    @config["changelog_label_mapping"]
  end

  def patch_level_labels
    @config["patch_level_labels"]
  end
end
