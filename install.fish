#!/usr/bin/env fish

# fish-api-keys installer
# Run: fish install.fish

set -l config_dir ~/.config/fish
set -l dest "$config_dir/api-keys.fish"
set -l conf "$config_dir/api-keys.conf"
set -l config_fish "$config_dir/config.fish"

# Copy the function file
cp api-keys.fish $dest
echo "✅ Installed api-keys.fish → $dest"

# Create key store from example if it doesn't exist
if not test -f $conf
    cp api-keys.conf.example $conf
    chmod 600 $conf
    echo "✅ Created api-keys.conf → $conf (permissions: 600)"
else
    echo "⏭  api-keys.conf already exists, skipping"
end

# Check if config.fish already sources api-keys.fish
if test -f $config_fish
    if not grep -q 'source.*api-keys.fish' $config_fish
        echo "" >> $config_fish
        echo "# API key manager" >> $config_fish
        echo "source $dest" >> $config_fish
        echo "✅ Added source line to config.fish"
    else
        echo "⏭  config.fish already sources api-keys.fish"
    end
else
    echo "⚠️  No config.fish found — add this manually:"
    echo "   source $dest"
end

echo ""
echo "Done! Edit your keys:  api edit"
echo "Then try:              api use anthropic work"
