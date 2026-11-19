require 'sinatra/base'
require 'json'
require 'thin'

class FakeCopyTunerApp < Sinatra::Base
  disable :show_exceptions

  def self.start
    Thread.new do
      if ENV['DEBUG']
        Thin::Logging.debug = true
      else
        Thin::Logging.silent = true
      end

      Rack::Handler::Thin.run self, Port: port
    end
  end

  def self.port
    ENV.fetch('COPY_TUNER_PORT', 3002).to_i
  end

  def self.add_project(api_key, s3_path_token: api_key)
    Project.create api_key, s3_path_token:
  end

  def self.reset
    Project.delete_all
  end

  def self.project(api_key)
    Project.find api_key
  end

  def with_project(key, finder: :find, missing_status: 404)
    case key
    when 'raise_error' then halt 500, { error: 'Blah ha' }.to_json
    when 'not_found' then halt 404, { error: 'No such project' }.to_json
    end

    project = Project.public_send(finder, key)
    halt missing_status, { error: 'No such project' }.to_json unless project
    yield project
  end

  # 本番の S3/CloudFront は存在しないパスに 404 ではなく 403 を返すので合わせる
  def with_project_by_s3_path_token(s3_path_token, &)
    with_project(s3_path_token, finder: :find_by_s3_path_token, missing_status: 403, &)
  end

  get '/api/v2/projects/:s3_path_token/published_blurbs.json' do |s3_path_token|
    with_project_by_s3_path_token(s3_path_token) do |project|
      etag project.etag
      project.published.to_json
    end
  end

  get '/api/v2/projects/:s3_path_token/draft_blurbs.json' do |s3_path_token|
    with_project_by_s3_path_token(s3_path_token) do |project|
      etag project.etag
      project.draft.to_json
    end
  end

  post '/api/v2/projects/:api_key/draft_blurbs' do |api_key|
    with_project(api_key) do |project|
      with_json_data do |data|
        project.update 'draft' => data
        201
      end
    end
  end

  def with_json_data
    if request.content_type == 'application/json'
      yield JSON.parse(request.body.read)
    else
      406
    end
  end

  post '/api/v2/projects/:api_key/deploys' do |api_key|
    with_project(api_key) do |project|
      project.deploy
      201
    end
  end

  class Project
    attr_reader :draft, :published, :api_key, :s3_path_token

    MUTEX = Mutex.new

    def self.create(api_key, s3_path_token: api_key)
      project = Project.new('api_key' => api_key, 's3_path_token' => s3_path_token)
      save project
      project
    end

    def self.find(api_key)
      find_by { |data| data[api_key] }
    end

    def self.find_by_s3_path_token(s3_path_token)
      find_by { |data| data.values.find { |h| h['s3_path_token'] == s3_path_token } }
    end

    def self.find_by
      open_project_data do |data|
        if (project_hash = yield(data))
          Project.new project_hash.dup
        end
      end
    end

    def self.delete_all
      open_project_data(&:clear)
    end

    def self.save(project)
      open_project_data do |data|
        data[project.api_key] = project.to_hash
      end
    end

    def self.open_project_data
      MUTEX.synchronize do
        project_file = File.expand_path('../../tmp/projects.json', __dir__)
        FileUtils.mkdir_p File.dirname(project_file)

        data =
          if File.exist? project_file
            JSON.parse(File.read(project_file))
          else
            {}
          end

        result = yield(data)

        File.write(project_file, data.to_json)

        result
      end
    end

    def initialize(attrs)
      @api_key = attrs['api_key']
      @s3_path_token = attrs['s3_path_token']
      @draft = attrs.fetch('draft', {})
      @etag = attrs.fetch('etag', 1)
      @published = attrs.fetch('published', {})
    end

    def to_hash
      {
        'api_key' => @api_key,
        's3_path_token' => @s3_path_token,
        'etag' => @etag,
        'draft' => @draft,
        'published' => @published,
      }
    end

    def update(attrs)
      @draft.update attrs['draft'] if attrs['draft']

      @published.update attrs['published'] if attrs['published']

      @etag += 1
      self.class.save self
    end

    def reload
      self.class.find api_key
    end

    def deploy
      @published.update @draft
      self.class.save self
    end

    def etag
      @etag.to_s
    end
  end
end
