# frozen_string_literal: true

class Discover::TaxonomyPresenter
  TAXONOMY_LABELS = {
    "3d" => "3D",
    "3d-assets" => "3D Assets",
    "3d-icons" => "3D Icons",
    "3d-modeling" => "3D Modeling",
    "3d-printing" => "3D Printing",
    "3dsmax" => "3ds Max",
    "ableton-live" => "Ableton Live",
    "accessories" => "Accessories",
    "accounting" => "Accounting",
    "action-and-adventure" => "Action & Adventure",
    "adobe" => "Adobe",
    "after-effects" => "After Effects",
    "albums" => "Albums",
    "alternative-and-indie" => "Alternative & Indie",
    "analytics" => "Analytics",
    "animating" => "Animating",
    "animation" => "Animation",
    "animations" => "Animations",
    "anime" => "Anime",
    "app-development" => "App Development",
    "architecture" => "Architecture",
    "artwork-and-commissions" => "Artwork & Commissions",
    "arvr" => "AR/VR",
    "asmr" => "ASMR",
    "assets" => "Assets",
    "assets-and-templates" => "Assets & Templates",
    "astrology" => "Astrology",
    "audio" => "Audio",
    "automotive" => "Automotive",
    "avatar-components" => "Avatar Components",
    "avatar-systems" => "Avatar Systems",
    "avatars" => "Avatars",
    "aws" => "AWS",
    "bags" => "Bags",
    "base" => "Base",
    "bases" => "Bases",
    "belts" => "Belts",
    "black-voices" => "Black Voices",
    "blender" => "Blender",
    "blues" => "Blues",
    "board-games" => "Board Games",
    "boating-and-fishing" => "Boating & Fishing",
    "bodysuits" => "Bodysuits",
    "boots" => "Boots",
    "bottoms" => "Bottoms",
    "branding" => "Branding",
    "bras" => "Bras",
    "broadway-and-vocalists" => "Broadway & Vocalists",
    "business-and-money" => "Business & Money",
    "business-cards" => "Business Cards",
    "c-sharp" => "C#",
    "canva" => "Canva",
    "character-design" => "Character Design",
    "childrens-books" => "Children's Books",
    "childrens-music" => "Children's Music",
    "chokers" => "Chokers",
    "christian" => "Christian",
    "cinema-4d" => "Cinema 4D",
    "classic-rock" => "Classic Rock",
    "classical" => "Classical",
    "classics" => "Classics",
    "classroom" => "Classroom",
    "clothing" => "Clothing",
    "comedy" => "Comedy",
    "comedy-and-miscellaneous" => "Comedy & Miscellaneous",
    "comics-and-graphic-novels" => "Comics & Graphic Novels",
    "companions" => "Companions",
    "cooking" => "Cooking",
    "cosplay" => "Cosplay",
    "country" => "Country",
    "courses" => "Courses",
    "crafts-and-dyi" => "Crafts & DYI",
    "crafts-for-children" => "Crafts for Children",
    "dance" => "Dance",
    "dance-and-electronic" => "Dance & Electronic",
    "dance-and-theater" => "Dance & Theater",
    "dating-and-relationships" => "Dating & Relationships",
    "design" => "Design",
    "digital-illustration" => "Digital Illustration",
    "documentary" => "Documentary",
    "drama" => "Drama",
    "drawing-and-painting" => "Drawing & Painting",
    "dresses" => "Dresses",
    "ears" => "Ears",
    "education" => "Education",
    "email" => "Email",
    "english" => "English",
    "entertainment" => "Entertainment",
    "entertainment-design" => "Entertainment Design",
    "entrepreneurship" => "Entrepreneurship",
    "exercise-and-workout" => "Exercise & Workout",
    "eyes" => "Eyes",
    "face" => "Face",
    "faith-and-spirituality" => "Faith & Spirituality",
    "fantasy" => "Fantasy",
    "fashion-design" => "Fashion Design",
    "feet" => "Feet",
    "female" => "Female",
    "fiction-books" => "Fiction Books",
    "figma" => "Figma",
    "films" => "Films",
    "fitness-and-health" => "Fitness & Health",
    "fl-studio" => "FL Studio",
    "folk" => "Folk",
    "followers" => "Followers",
    "fonts" => "Fonts",
    "footwear" => "Footwear",
    "foreign-language-and-international" => "Foreign Language & International",
    "gaming" => "Gaming",
    "gigs-and-side-projects" => "Gigs & Side Projects",
    "gloves" => "Gloves",
    "gospel" => "Gospel",
    "graphics" => "Graphics",
    "guitar" => "Guitar",
    "hair" => "Hair",
    "handheld" => "Handheld",
    "hard-rock-and-metal" => "Hard Rock & Metal",
    "hardware" => "Hardware",
    "harnesses" => "Harnesses",
    "hats" => "Hats",
    "heads" => "Heads",
    "headwear" => "Headwear",
    "healing" => "Healing",
    "history" => "History",
    "holiday-music" => "Holiday Music",
    "horns" => "Horns",
    "horror" => "Horror",
    "html" => "HTML",
    "hunting" => "Hunting",
    "hypnosis" => "Hypnosis",
    "icons" => "Icons",
    "illustration-brushes" => "Illustration Brushes",
    "illustration-kits" => "Illustration Kits",
    "illustration-textures-and-patterns" => "Illustration Textures & Patterns",
    "illustrator" => "Illustrator",
    "indesign" => "InDesign",
    "indian-cinema-and-bollywood" => "Indian Cinema & Bollywood",
    "indie-and-art-house" => "Indie & Art House",
    "industrial-design" => "Industrial Design",
    "instruments" => "Instruments",
    "interior-design" => "Interior Design",
    "investing" => "Investing",
    "ios-customization" => "iOS Customization",
    "jackets" => "Jackets",
    "javascript" => "Javascript",
    "jazz" => "Jazz",
    "jewelry" => "Jewelry",
    "kids-and-family" => "Kids & Family",
    "kits" => "Kits",
    "latin-music" => "Latin Music",
    "law" => "Law",
    "leggings" => "Leggings",
    "lego" => "Lego",
    "lgbtq" => "LGBTQ",
    "lingerie" => "Lingerie",
    "logic-pro" => "Logic Pro",
    "logos" => "Logos",
    "luts" => "LUTs",
    "magic" => "Magic",
    "male" => "Male",
    "management-and-leadership" => "Management & Leadership",
    "marketing-and-sales" => "Marketing & Sales",
    "marketing-and-social" => "Marketing & Social",
    "masks" => "Masks",
    "matcap" => "MatCap",
    "math" => "Math",
    "maya" => "Maya",
    "medicine" => "Medicine",
    "meditation" => "Meditation",
    "midi" => "MIDI",
    "mockups" => "Mockups",
    "modo" => "Modo",
    "movie" => "Movie",
    "music-and-sound-design" => "Music & Sound Design",
    "music-videos-and-concerts" => "Music Videos & Concerts",
    "mystery" => "Mystery",
    "mysticism" => "Mysticism",
    "networking-careers-and-jobs" => "Networking, Careers & Jobs",
    "new-age" => "New Age",
    "non-binary" => "Non-Binary",
    "nutrition" => "Nutrition",
    "opera-and-vocal" => "Opera & Vocal",
    "optimized" => "Optimized",
    "osc" => "OSC",
    "other" => "Other",
    "outdoors" => "Outdoors",
    "outfits" => "Outfits",
    "pants" => "Pants",
    "papercrafts" => "Papercrafts",
    "particle-systems" => "Particle Systems",
    "pbr" => "PBR",
    "performance" => "Performance",
    "personal-finance" => "Personal Finance",
    "philosophy" => "Philosophy",
    "photo-courses" => "Photo Courses",
    "photo-presets-and-actions" => "Photo Presets & Actions",
    "photography" => "Photography",
    "photoshop" => "Photoshop",
    "piano" => "Piano",
    "plugins" => "Plugins",
    "plushies" => "Plushies",
    "podcasts" => "Podcasts",
    "politics" => "Politics",
    "pop" => "Pop",
    "powerpoint" => "Powerpoint",
    "prefabs" => "Prefabs",
    "premiere-pro" => "Premiere Pro",
    "print-and-packaging" => "Print & Packaging",
    "procreate" => "Procreate",
    "productivity" => "Productivity",
    "programming" => "Programming",
    "props" => "Props",
    "psychology" => "Psychology",
    "python" => "Python",
    "quest" => "Quest",
    "rap-and-hip-hop" => "Rap & Hip-Hop",
    "raspberry-pi" => "Raspberry Pi",
    "react-js" => "React JS",
    "react-native" => "React Native",
    "real-estate" => "Real Estate",
    "recipes" => "Recipes",
    "recorded-music" => "Recorded Music",
    "reference-photos" => "Reference Photos",
    "resources" => "Resources",
    "rhythm-and-blues" => "R&B",
    "rigging" => "Rigging",
    "rock" => "Rock",
    "romance" => "Romance",
    "ruby" => "Ruby",
    "running" => "Running",
    "samples" => "Samples",
    "science" => "Science",
    "science-fiction" => "Science Fiction",
    "self-improvement" => "Self Improvement",
    "setup-scripts" => "Setup Scripts",
    "sewing" => "Sewing",
    "shaders" => "Shaders",
    "sheet-music" => "Sheet Music",
    "shirts" => "Shirts",
    "shoes" => "Shoes",
    "short-film" => "Short Film",
    "shorts" => "Shorts",
    "singles" => "Singles",
    "sketch" => "Sketch",
    "sketchup" => "SketchUp",
    "skirts" => "Skirts",
    "sleep-and-meditation" => "Sleep & Meditation",
    "social-media" => "Social Media",
    "social-studies" => "Social Studies",
    "socks" => "Socks",
    "software-and-plugins" => "Software & Plugins",
    "software-development" => "Software Development",
    "sound-design" => "Sound Design",
    "soundtracks" => "Soundtracks",
    "spark-ar-studio" => "Spark AR Studio",
    "specialties" => "Specialties",
    "species" => "Species",
    "spirituality" => "Spirituality",
    "sports" => "Sports",
    "sports-events" => "Sports Events",
    "spring-joints" => "Spring Joints",
    "standup" => "Standup",
    "stock" => "Stock",
    "stock-photos" => "Stock Photos",
    "stockings" => "Stockings",
    "streaming" => "Streaming",
    "subliminal-messages" => "Subliminal Messages",
    "sweaters" => "Sweaters",
    "swift" => "Swift",
    "swimsuits" => "Swimsuits",
    "tails" => "Tails",
    "tarot" => "Tarot",
    "tattoos" => "Tattoos",
    "teen-and-young-adult" => "Teen & Young Adult",
    "test-prep" => "Test Prep",
    "textures" => "Textures",
    "textures-and-patterns-2d" => "Textures & Patterns (2D)",
    "theater" => "Theater",
    "tools" => "Tools",
    "tops" => "Tops",
    "traditional-art" => "Traditional Art",
    "travel" => "Travel",
    "trekking" => "Trekking",
    "tutorials-guides" => "Tutorials & Guides",
    "udon" => "Udon",
    "udon-system" => "Udon System",
    "udon2" => "Udon 2",
    "ui-and-web" => "UI & Web",
    "underwear" => "Underwear",
    "unity" => "Unity",
    "unreal-engine" => "Unreal Engine",
    "vector-graphics" => "Vector Graphics",
    "vector-icons" => "Vector Icons",
    "vegan" => "Vegan",
    "video" => "Video",
    "video-assets-and-loops" => "Video Assets & Loops",
    "video-production-and-editing" => "Video Production & Editing",
    "videography" => "Videography",
    "vocal" => "Vocal",
    "voiceover" => "Voiceover",
    "vrchat" => "VRChat",
    "vscode" => "VSCode",
    "wallpapers" => "Wallpapers",
    "weapons" => "Weapons",
    "web-development" => "Web Development",
    "weddings" => "Weddings",
    "weight-loss-and-dieting" => "Weight Loss & Dieting",
    "wellness" => "Wellness",
    "western" => "Western",
    "wicca-witchcraft-and-paganism" => "Wicca, Witchcraft & Paganism",
    "wings" => "Wings",
    "woodworking" => "Woodworking",
    "wordpress" => "Wordpress",
    "world-constraints" => "World Constraints",
    "world-music" => "World Music",
    "worlds" => "Worlds",
    "writing-and-publishing" => "Writing & Publishing",
    "xd" => "XD",
    "yoga" => "Yoga",
    "zbrush" => "ZBrush"
  }

  def taxonomies_for_nav(recommended_products: nil)
    taxonomies = Rails.cache.fetch("taxonomies_for_nav", expires_in: 1.hour) do
      Taxonomy.all.eager_load(:taxonomy_stat).sort_by do |taxonomy|
        if taxonomy.slug == "other"
          [1, taxonomy.slug]
        else
          [-taxonomy.taxonomy_stat&.recent_sales_count.to_i, taxonomy.slug]
        end
      end.map do |taxonomy|
        {
          key: taxonomy.id.to_s,
          label: TAXONOMY_LABELS[taxonomy.slug],
          slug: taxonomy.slug,
          parent_key: taxonomy.parent_id&.to_s
        }
      end
    end

    taxonomy_ids = recommended_products&.filter_map(&:taxonomy_id)
    if taxonomy_ids.present?
      sorted_roots = (Taxonomy.includes(:self_and_ancestors).where(self_and_ancestors: { parent_id: nil }).find(taxonomy_ids)).each_with_object({}).with_index do |(taxonomy, hash), index|
        hash[taxonomy.self_and_ancestors.first.slug] ||= taxonomy_ids.size - index
      end
      taxonomies = taxonomies.sort_by.with_index { |taxonomy, index| [-(sorted_roots[taxonomy[:slug]] || 0), index] }
    end

    taxonomies
  end
end
