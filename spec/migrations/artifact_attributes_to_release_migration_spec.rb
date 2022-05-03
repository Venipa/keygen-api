# frozen_string_literal: true

require 'rails_helper'
require 'spec_helper'
require 'database_cleaner'
require 'sidekiq/testing'

DatabaseCleaner.strategy = :truncation, { except: ['event_types'] }

describe ArtifactAttributesToReleaseMigration do
  let(:account)                  { create(:account) }
  let(:product)                  { create(:product, account:) }
  let(:release_without_artifact) { create(:release, :unpublished, account:, product:) }
  let(:release_with_artifact)    { create(:release, :published, account:, product:) }

  before do
    Sidekiq::Testing.fake!
    StripeHelper.start
  end

  after do
    DatabaseCleaner.clean
    StripeHelper.stop
  end

  before do
    Versionist.configure do |config|
      config.current_version = '1.0'
      config.versions        = {
        '1.0' => [ArtifactAttributesToReleaseMigration],
      }
    end
  end

  context 'the release does not have an artifact' do
    subject { release_without_artifact }

    it 'should migrate a release artifact relationship' do
      migrator = Versionist::Migrator.new(from: '1.0', to: '1.0')
      data     = Keygen::JSONAPI.render(subject)

      expect(data).to_not include(
        data: include(
          attributes: include(
            platform: anything,
            filetype: anything,
            filename: anything,
            filename: anything,
            signature: anything,
            checksum: anything,
          ),
        ),
      )

      migrator.migrate!(data:)

      expect(data).to include(
        data: include(
          attributes: include(
            platform: nil,
            filetype: nil,
            filename: nil,
            filesize: nil,
            signature: nil,
            checksum: nil,
          ),
        ),
      )
    end
  end

  context 'the release has an artifact' do
    subject { release_with_artifact }

    it 'should migrate a release artifact relationship' do
      migrator = Versionist::Migrator.new(from: '1.0', to: '1.0')
      data     = Keygen::JSONAPI.render(subject)

      expect(data).to_not include(
        data: include(
          attributes: include(
            platform: anything,
            filetype: anything,
            filename: anything,
            filename: anything,
            signature: anything,
            checksum: anything,
          ),
        ),
      )

      migrator.migrate!(data:)

      expect(data).to include(
        data: include(
          attributes: include(
            platform: subject.artifact.platform.key,
            filetype: subject.artifact.filetype.key,
            filename: subject.artifact.filename,
            filesize: subject.artifact.filesize,
            signature: subject.artifact.signature,
            checksum: subject.artifact.checksum,
          ),
        ),
      )
    end
  end
end
