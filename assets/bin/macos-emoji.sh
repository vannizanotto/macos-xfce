#!/bin/bash
# macos-emoji.sh - macOS style emoji picker using rofi and xdotool

EMOJI_LIST="😀  Grinning Face
😃  Grinning Face with Big Eyes
😄  Grinning Face with Smiling Eyes
😁  Beaming Face with Smiling Eyes
😆  Grinning Squinting Face
😅  Grinning Face with Sweat
🤣  Rolling on the Floor Laughing
😂  Face with Tears of Joy
🙂  Slightly Smiling Face
🙃  Upside-Down Face
😉  Winking Face
😊  Smiling Face with Smiling Eyes
😇  Smiling Face with Halo
🥰  Smiling Face with Hearts
😍  Smiling Face with Heart-Eyes
🤩  Star-Struck
😘  Face Blowing a Kiss
😗  Kissing Face
☺️  Smiling Face
😚  Kissing Face with Closed Eyes
😙  Kissing Face with Smiling Eyes
🥲  Smiling Face with Tear
😋  Face Savoring Food
😛  Face with Tongue
😜  Winking Face with Tongue
🤪  Zany Face
😝  Squinting Face with Tongue
🤑  Money-Mouth Face
🤗  Hugging Face
🤭  Face with Hand Over Mouth
🤫  Shushing Face
🤔  Thinking Face
🤐  Zipper-Mouth Face
🤨  Face with Raised Eyebrow
😐  Neutral Face
😑  Expressionless Face
😶  Face Without Mouth
😏  Smirking Face
😒  Unamused Face
🙄  Face with Rolling Eyes
😬  Grimacing Face
🤥  Lying Face
😌  Relieved Face
😔  Pensive Face
😪  Sleepy Face
🤤  Drooling Face
😴  Sleeping Face
😷  Face with Medical Mask
🤒  Face with Thermometer
🤕  Face with Head-Bandage
🤢  Nauseated Face
🤮  Face Vomiting
🤧  Sneezing Face
🥵  Hot Face
🥶  Cold Face
🥴  Woozy Face
😵  Dizzy Face
🤯  Exploding Head
🤠  Cowboy Hat Face
🥳  Partying Face
😎  Smiling Face with Sunglasses
🤓  Nerd Face
🧐  Face with Monocle
😕  Confused Face
😟  Worried Face
🙁  Slightly Frowning Face
☹️  Frowning Face
😮  Face with Open Mouth
😯  Hushed Face
😲  Astonished Face
😳  Flushed Face
🥺  Pleading Face
😦  Frowning Face with Open Mouth
😧  Anguished Face
😨  Fearful Face
😰  Anxious Face with Sweat
😥  Sad but Relieved Face
😢  Crying Face
😭  Loudly Crying Face
😱  Face Screaming in Fear
😖  Confounded Face
😣  Persevering Face
😞  Disappointed Face
😓  Downcast Face with Sweat
😩  Weary Face
😫  Tired Face
🥱  Yawning Face
😤  Face with Steam From Nose
😡  Pouting Face
😠  Angry Face
🤬  Face with Symbols on Mouth
😈  Smiling Face with Horns
👿  Angry Face with Horns
💀  Skull
💩  Pile of Poo
🤡  Clown Face
👻  Ghost
👽  Alien
👾  Alien Monster
🤖  Robot
👍  Thumbs Up
👎  Thumbs Down
👏  Clapping Hands
🙌  Raising Hands
👐  Open Hands
🤲  Palms Up Together
🤝  Handshake
🙏  Folded Hands
❤️  Red Heart
🔥  Fire
✨  Sparkles
🎉  Party Popper
✅  Check Mark"

# Run rofi
SELECTION=$(echo "$EMOJI_LIST" | rofi -dmenu -i -p "Emoji")

if [ -n "$SELECTION" ]; then
    EMOJI=$(echo "$SELECTION" | awk '{print $1}')
    # Wait briefly for rofi to close and focus to return to previous window
    sleep 0.1
    # Type the emoji
    xdotool type --clearmodifiers "$EMOJI"
fi
