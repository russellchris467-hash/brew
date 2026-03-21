#!/usr/bin/env python3
"""
Tests for the interactive pentesting features:
  - Multi-layer chainer
  - Channel formatter
  - Console command dispatch
"""

import importlib.machinery
import importlib.util
import sys
import os
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from lib.chainer import chain_encode, chain_decode, METHODS
from lib.channel_formatter import format_for_channel, list_channels, CHANNEL_PROFILES


class TestChainer(unittest.TestCase):
    """Tests for multi-layer encoding chain."""

    def test_single_method_roundtrip(self):
        for method in METHODS:
            with self.subTest(method=method):
                r = chain_encode("hello", [method], key=42, noise=0.0)
                d = chain_decode(r['encoded'], [method], key=42)
                self.assertEqual(d['decoded'], "hello")

    def test_double_chain_roundtrip(self):
        r = chain_encode("secret", ['cipher', 'zwc'], key=42, noise=0.0)
        d = chain_decode(r['encoded'], ['cipher', 'zwc'], key=42)
        self.assertEqual(d['decoded'], "secret")

    def test_triple_chain_roundtrip(self):
        r = chain_encode("hi", ['regional', 'cipher', 'zwc'], key=42, noise=0.0)
        d = chain_decode(r['encoded'], ['regional', 'cipher', 'zwc'], key=42)
        self.assertEqual(d['decoded'], "hi")

    def test_chain_expansion_tracked(self):
        r = chain_encode("test", ['cipher', 'zwc'], key=42, noise=0.0)
        self.assertIn('steps', r)
        self.assertEqual(len(r['steps']), 2)
        self.assertEqual(r['steps'][0]['method'], 'cipher')
        self.assertEqual(r['steps'][1]['method'], 'zwc')
        self.assertIn('total_expansion', r)

    def test_unknown_method_raises(self):
        with self.assertRaises(ValueError):
            chain_encode("test", ['nonexistent'])

    def test_unicode_chain(self):
        msg = "caf\u00e9 \u2603"
        r = chain_encode(msg, ['cipher', 'vs'], key=99, noise=0.0)
        d = chain_decode(r['encoded'], ['cipher', 'vs'], key=99)
        self.assertEqual(d['decoded'], msg)


class TestChannelFormatter(unittest.TestCase):
    """Tests for channel-specific payload formatting."""

    def test_all_channels_format(self):
        payload = "test_payload"
        for ch_id in CHANNEL_PROFILES:
            with self.subTest(channel=ch_id):
                result = format_for_channel(payload, ch_id)
                self.assertIn('message', result)
                self.assertIn(payload, result['message'])
                self.assertEqual(result['payload_length'], len(payload))

    def test_unknown_channel_raises(self):
        with self.assertRaises(ValueError):
            format_for_channel("test", "nonexistent_channel")

    def test_custom_cover_text(self):
        result = format_for_channel("PAYLOAD", "slack", custom_cover="Hey! {payload} bye")
        self.assertEqual(result['message'], "Hey! PAYLOAD bye")

    def test_custom_cover_without_placeholder(self):
        result = format_for_channel("PAYLOAD", "slack", custom_cover="prefix ")
        self.assertEqual(result['message'], "prefix PAYLOAD")

    def test_length_warning_twitter(self):
        long_payload = "x" * 300
        result = format_for_channel(long_payload, "twitter")
        self.assertTrue(len(result['warnings']) > 0)

    def test_paste_channel_raw(self):
        result = format_for_channel("raw_data", "paste")
        self.assertEqual(result['message'], "raw_data")

    def test_list_channels(self):
        channels = list_channels()
        self.assertTrue(len(channels) >= 7)
        for ch in channels:
            self.assertIn('id', ch)
            self.assertIn('name', ch)
            self.assertIn('max_length', ch)


class TestConsoleDispatch(unittest.TestCase):
    """Tests for the interactive console command dispatch."""

    def setUp(self):
        import importlib.util
        filepath = os.path.join(os.path.dirname(__file__), '..', 'bin', 'hydra-interactive')
        loader = importlib.machinery.SourceFileLoader("hydra_interactive", filepath)
        spec = importlib.util.spec_from_loader("hydra_interactive", loader)
        mod = importlib.util.module_from_spec(spec)
        # Prevent argparse from consuming test runner args
        old_argv = sys.argv
        sys.argv = ['hydra-interactive']
        try:
            spec.loader.exec_module(mod)
        finally:
            sys.argv = old_argv
        self.HydraConsole = mod.HydraConsole

    def test_encode_decode_roundtrip(self):
        console = self.HydraConsole()
        console.dispatch('encode cipher "test message"')
        encoded = console.last_result
        self.assertTrue(len(encoded) > 0)
        console.dispatch(f'decode cipher {encoded}')
        self.assertEqual(console.last_result, "test message")

    def test_set_key(self):
        console = self.HydraConsole()
        console.dispatch('set key 99')
        self.assertEqual(console.cipher_key, 99)

    def test_set_channel(self):
        console = self.HydraConsole()
        console.dispatch('set channel slack')
        self.assertEqual(console.auto_channel, 'slack')

    def test_set_variable(self):
        console = self.HydraConsole()
        console.dispatch('set myvar hello_world')
        self.assertEqual(console.session_vars['myvar'], 'hello_world')
        console.dispatch('get myvar')

    def test_exit_returns_false(self):
        console = self.HydraConsole()
        self.assertFalse(console.dispatch('exit'))
        self.assertFalse(console.dispatch('quit'))

    def test_demo_runs(self):
        console = self.HydraConsole()
        console.dispatch('demo')

    def test_vars_runs(self):
        console = self.HydraConsole()
        console.dispatch('vars')

    def test_history_tracked(self):
        console = self.HydraConsole()
        console.dispatch('demo')
        console.dispatch('vars')
        self.assertEqual(len(console.cmd_history), 2)

    def test_inline_options(self):
        console = self.HydraConsole()
        console.dispatch('encode cipher --key 77 "test"')
        self.assertEqual(console.cipher_key, 77)


if __name__ == '__main__':
    unittest.main()
