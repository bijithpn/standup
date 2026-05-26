import xml.etree.ElementTree as ET
import sys
import os
from datetime import datetime

def generate_appcast(version, short_version, dmg_url, signature, file_size, appcast_path):
    # Register sparkle namespace
    ET.register_namespace('sparkle', 'http://www.andymatuschak.org/xml-namespaces/sparkle')
    
    if os.path.exists(appcast_path):
        tree = ET.parse(appcast_path)
        root = tree.getroot()
    else:
        root = ET.Element('rss', version='2.0')
        channel = ET.SubElement(root, 'channel')
        ET.SubElement(channel, 'title').text = 'standup Updates'
        ET.SubElement(channel, 'description').text = 'Most recent updates to standup.'
        ET.SubElement(channel, 'language').text = 'en'
    
    channel = root.find('channel')
    
    item = ET.Element('item')
    ET.SubElement(item, 'title').text = f'Version {short_version}'
    ET.SubElement(item, 'pubDate').text = datetime.now().strftime('%a, %d %b %Y %H:%M:%S +0000')
    
    enclosure = ET.SubElement(item, '{http://www.andymatuschak.org/xml-namespaces/sparkle}enclosure')
    enclosure.set('url', dmg_url)
    enclosure.set('{http://www.andymatuschak.org/xml-namespaces/sparkle}version', str(version))
    enclosure.set('{http://www.andymatuschak.org/xml-namespaces/sparkle}shortVersionString', short_version)
    enclosure.set('{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature', signature)
    enclosure.set('length', str(file_size))
    enclosure.set('type', 'application/octet-stream')
    
    # Insert at the beginning of the channel (after title/description)
    channel.insert(3, item)
    
    # Write back
    tree = ET.ElementTree(root)
    ET.indent(tree, space="    ", level=0)
    tree.write(appcast_path, encoding='utf-8', xml_declaration=True)

if __name__ == "__main__":
    if len(sys.argv) < 7:
        print("Usage: python generate_appcast.py <version> <short_version> <dmg_url> <signature> <file_size> <appcast_path>")
        sys.exit(1)
    
    generate_appcast(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6])
