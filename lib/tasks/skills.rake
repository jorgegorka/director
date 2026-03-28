namespace :skills do
  desc "Seed missing builtin skills for all existing companies"
  task reseed: :environment do
    skill_count = Dir[Rails.root.join("db/seeds/skills/*.yml")].size
    puts "Reseeding #{skill_count} builtin skills for all companies..."

    Company.find_each do |company|
      before_count = company.skills.builtin.count
      company.seed_default_skills!
      after_count = company.skills.builtin.count
      created = after_count - before_count

      if created > 0
        puts "  #{company.name}: created #{created} new skills (#{after_count} total builtin)"
      else
        puts "  #{company.name}: all #{after_count} builtin skills present"
      end
    end

    puts "Done."
  end
end
