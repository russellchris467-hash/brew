"""
Channel Formatter - Payload Delivery Profiling
================================================
Formats encoded payloads for specific delivery channels (Slack, Discord,
Teams, email, SMS, etc.) with channel-appropriate cover text.

FOR AUTHORIZED SECURITY TESTING ONLY.
"""

from __future__ import annotations

import random

# Channel-specific cover templates
# These provide plausible cover text for different messaging platforms
CHANNEL_PROFILES = {
    'slack': {
        'name': 'Slack',
        'max_length': 40000,
        'templates': [
            "Hey team! Great work today {payload} :tada:",
            "Standup update: all good here {payload}",
            "Quick question {payload} thanks!",
            "LGTM {payload}",
            "Reviewed and approved {payload}",
        ],
        'notes': 'Slack renders ZWC and VS invisibly. Emoji cipher blends with reactions.',
    },
    'discord': {
        'name': 'Discord',
        'max_length': 2000,
        'templates': [
            "gg wp {payload}",
            "lets gooo {payload}",
            "nice one! {payload}",
            "brb {payload}",
            "check this out {payload}",
        ],
        'notes': 'Discord 2000 char limit. ZWC works well. Nitro raises limit to 4000.',
    },
    'teams': {
        'name': 'Microsoft Teams',
        'max_length': 28000,
        'templates': [
            "Thanks for the update {payload}",
            "Sounds good, let me know {payload}",
            "Meeting notes attached {payload}",
            "Please review when you get a chance {payload}",
        ],
        'notes': 'Teams may strip some ZWC on paste. VS method preferred.',
    },
    'email': {
        'name': 'Email (Subject)',
        'max_length': 998,
        'templates': [
            "Re: Q3 Report {payload}",
            "Follow up: Project Alpha {payload}",
            "Quick sync {payload}",
            "FYI {payload}",
        ],
        'notes': 'Subject line encoding. Body allows much more. Watch for mail filters.',
    },
    'sms': {
        'name': 'SMS/iMessage',
        'max_length': 1600,
        'templates': [
            "On my way! {payload}",
            "Sounds good {payload}",
            "Got it {payload}",
            "See you there {payload}",
        ],
        'notes': 'Carrier-dependent. iMessage preserves Unicode well. SMS may strip.',
    },
    'twitter': {
        'name': 'Twitter/X',
        'max_length': 280,
        'templates': [
            "{payload}",
            "This {payload}",
            "Interesting {payload}",
        ],
        'notes': '280 char limit includes invisible chars! ZWC counts toward limit.',
    },
    'paste': {
        'name': 'Raw Paste',
        'max_length': None,
        'templates': ["{payload}"],
        'notes': 'Raw output, no cover text. Use with clipboard or file output.',
    },
}


def format_for_channel(payload: str, channel: str, custom_cover: str | None = None) -> dict:
    """
    Wrap an encoded payload in channel-appropriate cover text.

    Parameters
    ----------
    payload : str
        The already-encoded steganographic payload.
    channel : str
        Target channel name (slack, discord, teams, email, sms, twitter, paste).
    custom_cover : str, optional
        Custom cover text. Use {payload} as placeholder.

    Returns
    -------
    dict
        Formatted result with message, stats, and warnings.
    """
    if channel not in CHANNEL_PROFILES:
        raise ValueError(f"Unknown channel: {channel}. Available: {', '.join(CHANNEL_PROFILES)}")

    profile = CHANNEL_PROFILES[channel]

    if custom_cover:
        if '{payload}' in custom_cover:
            message = custom_cover.replace('{payload}', payload)
        else:
            message = custom_cover + payload
    else:
        template = random.choice(profile['templates'])
        message = template.replace('{payload}', payload)

    result = {
        'channel': profile['name'],
        'message': message,
        'total_length': len(message),
        'payload_length': len(payload),
        'cover_length': len(message) - len(payload),
        'notes': profile['notes'],
        'warnings': [],
    }

    max_len = profile['max_length']
    if max_len and len(message) > max_len:
        result['warnings'].append(
            f"Message exceeds {profile['name']} limit ({len(message)}/{max_len} chars). "
            f"Payload may be truncated."
        )

    return result


def list_channels() -> list[dict]:
    """List all available channel profiles with their limits."""
    return [
        {
            'id': ch_id,
            'name': profile['name'],
            'max_length': profile['max_length'],
            'notes': profile['notes'],
        }
        for ch_id, profile in CHANNEL_PROFILES.items()
    ]
