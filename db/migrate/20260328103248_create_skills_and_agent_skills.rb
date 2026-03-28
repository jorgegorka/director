class CreateSkillsAndAgentSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :skills do |t|
      t.references :company, null: false, foreign_key: true
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.text :markdown, null: false
      t.string :category
      t.boolean :builtin, default: true, null: false
      t.timestamps
    end

    add_index :skills, [ :company_id, :key ], unique: true
    add_index :skills, [ :company_id, :category ]

    create_table :agent_skills do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :skill, null: false, foreign_key: true
      t.timestamps
    end

    add_index :agent_skills, [ :agent_id, :skill_id ], unique: true
  end
end
