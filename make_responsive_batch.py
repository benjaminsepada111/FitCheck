#!/usr/bin/env python3
"""
Batch convert Flutter files to use responsive design utilities.
This script automates the conversion of fixed dimensions to responsive equivalents.
"""

import re
import os
import sys
from pathlib import Path

class ResponsiveConverter:
    def __init__(self, file_path):
        self.file_path = file_path
        self.content = ""
        self.modified = False

    def read_file(self):
        """Read the file content"""
        with open(self.file_path, 'r', encoding='utf-8') as f:
            self.content = f.read()

    def write_file(self):
        """Write the modified content back"""
        if self.modified:
            with open(self.file_path, 'w', encoding='utf-8') as f:
                f.write(self.content)
            print(f"✅ Updated: {self.file_path}")
        else:
            print(f"⏭️  Skipped (already responsive): {self.file_path}")

    def add_imports(self):
        """Add responsive imports if not present"""
        responsive_import = "import 'package:capstone_project/utils/responsive_utils.dart';"
        widgets_import = "import 'package:capstone_project/widgets/responsive_widgets.dart';"

        if responsive_import not in self.content:
            # Find the last import statement
            import_pattern = r'(import\s+[\'"].*?[\'"];)'
            imports = list(re.finditer(import_pattern, self.content))

            if imports:
                last_import = imports[-1]
                insert_pos = last_import.end()
                self.content = (
                    self.content[:insert_pos] +
                    f"\n{responsive_import}\n{widgets_import}" +
                    self.content[insert_pos:]
                )
                self.modified = True

    def replace_edge_insets(self):
        """Replace EdgeInsets with responsive versions"""
        patterns = [
            # EdgeInsets.all(X)
            (r'EdgeInsets\.all\((\d+(?:\.\d+)?)\)',
             r'EdgeInsets.all(r.size(\1))'),

            # EdgeInsets.symmetric with numbers
            (r'EdgeInsets\.symmetric\(horizontal:\s*(\d+(?:\.\d+)?),\s*vertical:\s*(\d+(?:\.\d+)?)\)',
             r'r.paddingSymmetric(horizontal: \1, vertical: \2)'),
            (r'EdgeInsets\.symmetric\(vertical:\s*(\d+(?:\.\d+)?),\s*horizontal:\s*(\d+(?:\.\d+)?)\)',
             r'r.paddingSymmetric(horizontal: \2, vertical: \1)'),
            (r'EdgeInsets\.symmetric\(horizontal:\s*(\d+(?:\.\d+)?)\)',
             r'EdgeInsets.symmetric(horizontal: r.size(\1))'),
            (r'EdgeInsets\.symmetric\(vertical:\s*(\d+(?:\.\d+)?)\)',
             r'EdgeInsets.symmetric(vertical: r.size(\1))'),

            # EdgeInsets.only
            (r'EdgeInsets\.only\(([^)]+)\)', self._replace_only_insets),

            # EdgeInsets.fromLTRB
            (r'EdgeInsets\.fromLTRB\((\d+(?:\.\d+)?),\s*(\d+(?:\.\d+)?),\s*(\d+(?:\.\d+)?),\s*(\d+(?:\.\d+)?)\)',
             r'EdgeInsets.fromLTRB(r.size(\1), r.size(\2), r.size(\3), r.size(\4))'),
        ]

        for pattern, replacement in patterns:
            if callable(replacement):
                self.content = re.sub(pattern, replacement, self.content)
            else:
                new_content = re.sub(pattern, replacement, self.content)
                if new_content != self.content:
                    self.content = new_content
                    self.modified = True

    def _replace_only_insets(self, match):
        """Helper to replace EdgeInsets.only parameters"""
        params = match.group(1)
        # Replace individual values
        params = re.sub(r'left:\s*(\d+(?:\.\d+)?)', r'left: r.size(\1)', params)
        params = re.sub(r'top:\s*(\d+(?:\.\d+)?)', r'top: r.size(\1)', params)
        params = re.sub(r'right:\s*(\d+(?:\.\d+)?)', r'right: r.size(\1)', params)
        params = re.sub(r'bottom:\s*(\d+(?:\.\d+)?)', r'bottom: r.size(\1)', params)
        return f'EdgeInsets.only({params})'

    def replace_border_radius(self):
        """Replace BorderRadius.circular with responsive version"""
        pattern = r'BorderRadius\.circular\((\d+(?:\.\d+)?)\)'
        new_content = re.sub(pattern, r'BorderRadius.circular(r.size(\1))', self.content)
        if new_content != self.content:
            self.content = new_content
            self.modified = True

    def replace_sized_box(self):
        """Replace const SizedBox with ResponsiveGap"""
        patterns = [
            (r'const\s+SizedBox\(height:\s*(\d+(?:\.\d+)?)\)', r'ResponsiveGap(\1)'),
            (r'const\s+SizedBox\(width:\s*(\d+(?:\.\d+)?)\)', r'ResponsiveGap.horizontal(\1)'),
            (r'SizedBox\(height:\s*(\d+(?:\.\d+)?)\)', r'ResponsiveSizedBox(height: \1)'),
            (r'SizedBox\(width:\s*(\d+(?:\.\d+)?)\)', r'ResponsiveSizedBox(width: \1)'),
            (r'SizedBox\(width:\s*(\d+(?:\.\d+)?),\s*height:\s*(\d+(?:\.\d+)?)\)',
             r'ResponsiveSizedBox(width: \1, height: \2)'),
            (r'SizedBox\(height:\s*(\d+(?:\.\d+)?),\s*width:\s*(\d+(?:\.\d+)?)\)',
             r'ResponsiveSizedBox(width: \2, height: \1)'),
        ]

        for pattern, replacement in patterns:
            new_content = re.sub(pattern, replacement, self.content)
            if new_content != self.content:
                self.content = new_content
                self.modified = True

    def replace_with_opacity(self):
        """Replace .withOpacity() with .withValues(alpha:)"""
        pattern = r'\.withOpacity\(([^)]+)\)'
        new_content = re.sub(pattern, r'.withValues(alpha: \1)', self.content)
        if new_content != self.content:
            self.content = new_content
            self.modified = True

    def add_responsive_context(self):
        """Add 'final r = context.responsive;' in build methods"""
        # Find build methods that don't have responsive context
        build_pattern = r'(@override\s+)?Widget\s+build\(BuildContext\s+context\)\s*\{'

        def add_r_declaration(match):
            method_start = match.group(0)
            # Check if 'final r = context.responsive;' already exists nearby
            next_100_chars = self.content[match.end():match.end()+200]
            if 'final r = context.responsive' in next_100_chars or 'final r = Responsive(context)' in next_100_chars:
                return method_start
            return method_start + '\n    final r = context.responsive;'

        new_content = re.sub(build_pattern, add_r_declaration, self.content)
        if new_content != self.content:
            self.content = new_content
            self.modified = True

    def process(self):
        """Run all conversion steps"""
        print(f"Processing: {self.file_path}")
        self.read_file()
        self.add_imports()
        self.add_responsive_context()
        self.replace_with_opacity()
        self.replace_edge_insets()
        self.replace_border_radius()
        self.replace_sized_box()
        self.write_file()

def main():
    """Main function to process files"""
    # List of files to convert
    files_to_convert = [
        "lib/FoodPage/add_food_sheet.dart",
        "lib/FoodPage/foodlogger.dart",
        "lib/FoodPage/recommendedfoods.dart",
        "lib/WorkoutPage/add_workout_sheet.dart",
        "lib/WorkoutPage/add_workout_sheet_v2.dart",
        "lib/WorkoutPage/workout_history_page.dart",
        "lib/NotificationSettingsPage.dart",
        "lib/MainPage/daily_logs.dart",
        "lib/MainPage/challenge_summary_page.dart",
        "lib/MainPage/challenge_calendar.dart",
        "lib/MainPage/weekly_checkin_wizard.dart",
        "lib/MainPage/create_challenge_sheet.dart",
        "lib/MainPage/challenge_history_sheet.dart",
        "lib/MainPage/add_milestone_sheet.dart",
        "lib/MainPage/milestone_preview.dart",
        "lib/MainPage/video_preview_page.dart",
        "lib/MainPage/weekly_checkin_dialog.dart",
    ]

    base_path = Path(__file__).parent

    for file_path in files_to_convert:
        full_path = base_path / file_path
        if full_path.exists():
            converter = ResponsiveConverter(str(full_path))
            try:
                converter.process()
            except Exception as e:
                print(f"❌ Error processing {file_path}: {e}")
        else:
            print(f"⚠️  File not found: {file_path}")

    print("\n✅ Batch conversion complete!")
    print("⚠️  Please review the changes and run 'flutter analyze' to check for errors.")
    print("⚠️  You may need to manually adjust some font sizes to add min/max values.")

if __name__ == "__main__":
    main()
