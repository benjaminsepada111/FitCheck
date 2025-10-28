# Achievement Badge Images

This folder contains custom badge images for achievements.

## Image Requirements

- **Format**: PNG (recommended for transparency)
- **Size**: Recommended 512x512 pixels or higher (will be scaled to 60x60 in app)
- **Shape**: Square images work best (will be displayed in a circle)
- **Background**: Transparent background recommended

## Image Naming

The following images are used for achievements:

1. `1.png` - Conqueror - Complete your first challenge
2. `Fire.png` - Gourmand - Consume 100,000 calories total
3. `Calendar.png` - Steadfast - Log in for 7 days
4. `Camera.png` - Perseverance - Upload progress photos for 7 days
5. `Trophy.png` - Discipline - Log meals for 30 days
6. `Crown.png` - Warrior - Complete 50 workouts
7. `Star.png` - Used as the icon in the Profile page for the Achievements card

## Visual Effects

- **Unlocked achievements**: Will display the full-color image with a colored shadow glow
- **Locked achievements**: Will display the image in grayscale
- **Fallback**: If an image fails to load, the app will automatically fall back to showing an icon

## Tips for Best Results

1. Design badges with bold, clear imagery that works well at small sizes
2. Use vibrant colors that match your app's color scheme
3. Ensure important details are in the center (edges may be slightly cropped by the circular frame)
4. Test both unlocked (full color) and locked (grayscale) versions

## How It Works

The achievement service (`lib/services/user_achievement_service.dart`) defines each achievement with an optional `image` field. When an image path is provided, the app will:

1. Try to load the custom badge image
2. Apply grayscale filter if the achievement is locked
3. Fall back to icon if the image fails to load
4. Display with appropriate shadow and border effects

## Adding More Achievements

To add a new achievement with a custom badge:

1. Add the image file to this folder (e.g., `MyBadge.png`)
2. Update `achievementDefinitions` in `lib/services/user_achievement_service.dart`:

   ```dart
   'new_achievement_id': {
     'title': 'Achievement Name',
     'description': 'Achievement description',
     'icon': 'fallback_icon_name', // Fallback icon if image fails
     'image': 'assets/images/achievements/MyBadge.png',
     'color': 0xFFCOLORCODE,
     'condition': 'stat_name',
     'threshold': value,
   }
   ```

3. The images you add will automatically appear in the Achievements page
4. Restart your app to see the changes

Happy designing! 🎨
