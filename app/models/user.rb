class User < ApplicationRecord
  # The default 15-minute expiry fits "check your email now"; this token
  # also doubles as the invite/rescue link (Admin::UsersController), handed
  # over out of band, so 24 hours fits better without weakening it.
  has_secure_password reset_token: { expires_in: 24.hours }
  has_many :sessions, dependent: :destroy

  # Notebooks are private to whoever created them — no per-notebook
  # sharing or permission model. Removing an account removes its
  # notebooks with it; the admin confirmation UI spells that out first.
  has_many :notebooks, -> { order(:position) }, dependent: :destroy
  has_many :folders, through: :notebooks
  has_many :notes, through: :notebooks
  has_many :todo_items, through: :notes

  # Where the user left off — HomeController falls back to these when a
  # visit carries no notebook_id/folder_id param, so a fresh session (a
  # cleared cache, a new device, the server restarting) resumes where the
  # sidebar was instead of always landing on the first notebook/folder.
  belongs_to :last_notebook, class_name: "Notebook", optional: true
  belongs_to :last_folder, class_name: "Folder", optional: true

  # member: a normal note-taking account. admin: manages logins (inviting
  # teammates, issuing reset links) and doesn't use the notebook UI at all.
  enum :role, { member: 0, admin: 1 }, default: :member

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :registered_at, presence: true
  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }, allow_nil: true

  before_validation :assign_registered_at, on: :create

  private
    def assign_registered_at
      self.registered_at ||= Time.current
    end
end
