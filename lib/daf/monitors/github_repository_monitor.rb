require 'daf/monitor'
require 'net/http'
require 'json'

module DAF
  # Monitors a github repository for updates at periodic intervals
  class GithubRepositoryMonitor < Monitor
    attr_option :owner, String, :required
    attr_option :repository, String, :required
    attr_option :branch, String, :required
    attr_option :frequency, Integer, :required
    attr_output :sha, String

    GITHUB_URI_PREFIX = 'https://api.github.com/'

    def block_until_triggered
      head_sha = github_head_sha(@owner, @repository, @branch)
      loop do
        sleep @frequency
        new_sha = github_head_sha(@owner, @repository, @branch)
        next unless new_sha != head_sha
        @sha = new_sha
      end
    end

    def github_head_sha(owner, repo, branch)
      uri = refs_uri(owner, repo, branch)
      begin
        response_body = Net::HTTP.get_response(URI.parse(uri)).body
        parse_commit_sha(response_body)
      rescue
        # Replace with actual logger in future...
        STDERR.puts 'HTTP connection failed'
      end
    end

    def parse_commit_sha(body)
      response = JSON.parse(body)
      response['object']['sha']
    end

    def refs_uri(owner, repo, branch)
      GITHUB_URI_PREFIX +
        "repos/#{owner.value}/#{repo.value}/git/refs/heads/#{branch.value}"
    end
  end
end
