---
name: flow-documentation
description: "Create professional Salesforce Flow documentation from .flow-meta.xml files with architectural formatting and PDF output. Supports both Google Drive and local filesystem sources. Uses sfdx-hardis for markdown generation and applies AI Instructions for professional documentation."
---

## Step 0 — start telemetry (REQUIRED, FIRST STEP)

Before doing anything else, call:

```
telemetry.skill_start({
  skill_name: "flow-documentation",
  input_summary: "<short, non-sensitive summary of the user's request>"
})
```

**Save the returned `invocation_id`** — you will need it in Step N.

Do NOT proceed to the user's task if `skill_start` returns an error. Surface
the error and stop.

---

# Salesforce Flow Documentation with Hardix

## Skill Overview

This skill creates **architectural documentation** from Salesforce Flow metadata files. It transforms raw Flow metadata into professional, human-readable PDF documents following specified formatting guidelines.

**Prerequisites:**
- Google authorization via `gog` skill (for Google Drive sources)
- `sfdx-hardis` plugin installed (for markdown generation)
- Python 3 with `reportlab` library (for PDF generation)

---

## Page Configuration

| Property | Value |
|----------|-------|
| Page Size | A4 |
| Orientation | Portrait |
| Top Margin | 25 mm |
| Bottom Margin | 25 mm |
| Left Margin | 20 mm |
| Right Margin | 20 mm |

---

## Typography

| Element | Style | Font | Size |
|---------|-------|------|------|
| Body Text | Regular | Helvetica | 12 pt |
| H1 | Bold | Helvetica | 18 pt |
| H2 | Bold | Helvetica | 14 pt |
| H3 | Bold | Helvetica | 12 pt |
| Table Text | Regular | Helvetica | 10–12 pt |

---

## Spacing Rules

| Element | Spacing |
|---------|---------|
| Line spacing | 1.15 – 1.3 |
| Space after H1 | 12–16 pt |
| Space after H2 | 10–12 pt |
| Space after H3 | 8–10 pt |
| Space between sections | 16–20 pt |

---

## Document Structure

### Heading Hierarchy

| Level | Usage | Format |
|-------|-------|--------|
| H1 | Main Sections | `# 1. Heading`, `# 2. Heading`, etc. |
| H2 | Subsections | `## Heading` |

### Separator
- Use `___` (triple underscore) between major sections
- Rendered as single horizontal line in PDF

### Bullet Rules
- Use clean bullet points (•)
- Keep each bullet ≤ 1 line ideally
- Maintain consistent indentation

---

## Document Content Template

### 1. Overview & Purpose

**Flow Details**
- Flow Name: `<Extract from XML>`
- Type: `<Screen Flow | Record Triggered Flow | Auto Launched Flow>`
- Trigger: `<Extract from XML if applicable>`
- Status: `<Extract from XML>`
- API Version: `<Extract from XML>`

**Purpose**
Provide a concise business-friendly summary in 1-2 sentences.

___

### 2. Flow Characteristics

| Attribute | Value |
|-----------|-------|
| Invocation | `<Screen Flow | Record Triggered | Auto Launched>` |
| Input Variable | `<Object name or User Input>` |
| Mode | `<Synchronous | Asynchronous>` |
| Output | `<Created Records | Updated Records | etc.>` |
| Navigation | `<Sequential | Branch on N decisions>` |

___

### 3. High-Level Process Flow

Step 1: `<Screen or action name>`
Step 2: `<Screen or action name>`
Step 3: Create Records (list)
Step 4: Update Records (list)
...

___

### 4. Architectural Summary

• Bullet point 1
• Bullet point 2
• Bullet point 3
• Bullet point 4
• Bullet point 5

---

## Content Processing Rules

### 1. Extraction
- Parse `.md` flexibly
- Normalize inconsistent formatting
- Get flow name from sfdx-hardis output (most accurate)
- Get flow type from node types (screens = Screen Flow, etc.)

### 2. Smart Inference
Infer missing:
- Flow type from presence of screens/record triggers
- Outputs from record creates/updates
- Navigation from decisions
- Purpose from flow type and nodes

### 3. Business Translation
Convert:
- API names → readable labels
- Technical logic → business-friendly explanation

---

## Output File Naming Convention

The output PDF file name is derived from the input XML file name:
- `File1.flow-meta.xml` → `File1.pdf`
- `File2.flow-meta.xml` → `File2.pdf`
- `Account_Update.flow-meta.xml` → `Account_Update.pdf`

**Important:** The `.flow-meta.xml` extension is removed, keeping only the base name with `.pdf` extension.

---

## Workflow

```
1. Get flow-meta.xml (from Google Drive or local folder)
2. Use sfdx-hardis to create .md file
3. Analyze .md file and create Architectural Documentation content
4. Apply formatting and styling
5. Create PDF document
6. Save PDF to specified location
7. Remove temporary .md file
```

---

## Step-by-Step Execution

### Step 1: Get Flow XML

Ask user for source location:
- **Google Drive:** Provide folder name or folder ID
- **Local filesystem:** Provide path to `.flow-meta.xml` file(s)

For Google Drive:
```
gog drive search '"<folder_id>" in parents and name contains "flow-meta"'
gog drive download <file_id> --out <local_path>
```

### Step 2: Generate Markdown

Run sfdx-hardis to convert XML to markdown:
```
sfdx hardis:doc:flow2markdown \
  --inputfile <path/to/flow-meta.xml> \
  --outputfile <temp_output.md> \
  --skipauth
```

### Step 3: Create Architectural Documentation

Analyze the markdown file and create structured documentation:
1. Extract Flow metadata (name, type, trigger, status, API version)
2. Determine flow type: Screen Flow (has screens), Record Triggered (has triggers), Auto Launched
3. Create concise business-friendly purpose summary (1-2 sentences)
4. Build Flow Characteristics table (plain text, no bold)
5. Produce High-Level Process Flow (Step 1, Step 2... format)
6. Write Architectural Summary (4-5 simple bullet points)

### Step 4: Generate PDF

Create PDF with proper formatting using Python/reportlab:
```
python3 generate_pdf.py <markdown_file> <output_pdf>
```

### Step 5: Save to Target Location

For Google Drive:
```
gog drive upload <pdf_file> --parent <folder_id>
```

For local storage:
```
cp <pdf_file> <destination_path>
```

### Step 6: Clean Up

Remove temporary markdown file:
```
rm -f <temp_markdown.md>
```

---

## Key Commands

| Task | Command |
|------|---------|
| Verify gog auth | `gog auth list` |
| Search Drive | `gog drive search '<query>' --max 10` |
| Download file | `gog drive download <id> --out <path>` |
| Upload file | `gog drive upload <file> --parent <folder_id>` |
| Generate Markdown | `sfdx hardis:doc:flow2markdown --inputfile <xml> --outputfile <md> --skipauth` |
| Generate PDF | `python3 generate_pdf.py <md_file> <pdf_output>` |

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Missing Flow metadata | Infer from filename or mark as "Unknown" |
| Complex branching | Summarize into 5-8 logical phases |
| Large flows | Cap process flow at 8 bullet points |
| No PDF tools | Output clean markdown with printing instructions |
| Google auth missing | Prompt user to run `gog auth login` |

---

## Verification Checklist

Before finishing, confirm:
- [ ] All 4 sections present with numbered headers (1. Overview, 2. Flow Characteristics, etc.)
- [ ] Section headers properly numbered (1. Overview & Purpose, 2. Flow Characteristics, etc.)
- [ ] Flow Details includes: Flow Name, Type, Trigger, Status, API Version
- [ ] Type is properly categorized (Screen Flow / Record Triggered Flow / Auto Launched Flow)
- [ ] Table uses plain text (no bold formatting)
- [ ] High-Level Process Flow uses Step 1, Step 2 format (no Action:/Data:/Decisions:)
- [ ] Architectural Summary has 4-5 simple bullet points (no sub-bullets)
- [ ] Separator is `___` (single line)
- [ ] PDF uses correct page configuration (A4, Portrait, margins)
- [ ] PDF saved to target location
- [ ] Temporary .md file cleaned up

---

## Important Notes

**This is NOT a technical reference manual.** This is **architectural documentation** for:
- Business stakeholders (understand what flow does)
- Developers (reference during maintenance)
- Architects (review design quality)

**Tone priority:** Professional, crisp, business-friendly — NOT technical, verbose.

**Keep it simple:** Bullet points over paragraphs, short over long.

---

End of Skill Documentation


===== SCRIPTS/generate_pdf.py =====

#!/usr/bin/env python3
"""
Generate professional PDF from Salesforce Flow Architectural Documentation.
Follows the Hardix skill specifications:
- A4 Portrait
- Margins: Top 25mm, Bottom 25mm, Left 20mm, Right 20mm
- Typography: Arial 12pt body, 18pt H1, 14pt H2, 12pt H3
- Spacing: 1.15-1.3 line spacing
"""

import sys
import re
import os
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm, inch

# Page configuration (in mm)
TOP_MARGIN = 25 * mm
BOTTOM_MARGIN = 25 * mm
LEFT_MARGIN = 20 * mm
RIGHT_MARGIN = 20 * mm

# Typography (in points)
BODY_FONT_SIZE = 12
H1_FONT_SIZE = 18
H2_FONT_SIZE = 14
H3_FONT_SIZE = 12

def get_body_style():
    """Get body text style - Helvetica 12pt, line spacing 1.15-1.3"""
    return ParagraphStyle(
        'BodyText',
        fontName='Helvetica',
        fontSize=BODY_FONT_SIZE,
        leading=BODY_FONT_SIZE * 1.2,
        spaceAfter=6
    )

def get_h1_style():
    """Get H1 style - Helvetica-Bold 18pt, space after 14pt"""
    return ParagraphStyle(
        'H1',
        fontName='Helvetica-Bold',
        fontSize=H1_FONT_SIZE,
        leading=H1_FONT_SIZE * 1.2,
        spaceAfter=14,
        spaceBefore=0,
        textColor=colors.black
    )

def get_h2_style():
    """Get H2 style - Helvetica-Bold 14pt, space after 11pt"""
    return ParagraphStyle(
        'H2',
        fontName='Helvetica-Bold',
        fontSize=H2_FONT_SIZE,
        leading=H2_FONT_SIZE * 1.2,
        spaceAfter=11,
        spaceBefore=16,
        textColor=colors.black
    )

def get_h3_style():
    """Get H3 style - Helvetica-Bold 12pt, space after 9pt"""
    return ParagraphStyle(
        'H3',
        fontName='Helvetica-Bold',
        fontSize=H3_FONT_SIZE,
        leading=H3_FONT_SIZE * 1.2,
        spaceAfter=9,
        spaceBefore=12,
        textColor=colors.black
    )

def make_section_separator():
    """Create a visual separator between major sections."""
    return [
        Spacer(1, 18),
        Paragraph('─' * 80, get_body_style()),
        Spacer(1, 18)
    ]

def parse_markdown_to_elements(md_content):
    """Parse markdown content and create PDF elements."""
    elements = []
    
    body = get_body_style()
    h1 = get_h1_style()
    h2 = get_h2_style()
    h3 = get_h3_style()
    
    lines = md_content.split('\n')
    i = 0
    in_table = False
    table_data = []
    
    while i < len(lines):
        line = lines[i].strip()
        
        # Skip empty lines at start
        if not line and not in_table:
            i += 1
            continue
        
        # Skip mermaid diagrams
        if line.startswith('```') or line.startswith('%%'):
            i += 1
            continue
        
        # Skip HTML comments
        if line.startswith('<!--') or line.startswith('-->'):
            i += 1
            continue
        
        # Handle separators
        if line.startswith('---'):
            elements.extend(make_section_separator())
            i += 1
            continue
        
        # Handle H1 (Main Sections: # 1., # 2., etc.)
        if re.match(r'^# \d+\.', line):
            elements.extend(make_section_separator())
            text = re.sub(r'^# \d+\.\s*', '', line)
            elements.append(Paragraph(text, h1))
            elements.append(Spacer(1, 8))
            i += 1
            continue
        
        # Handle H2 (Subsections: ## )
        if line.startswith('## '):
            elements.append(Paragraph(line[3:], h2))
            i += 1
            continue
        
        # Handle H3 (Steps: ### Step X:)
        if line.startswith('### '):
            elements.append(Paragraph(line[4:], h3))
            i += 1
            continue
        
        # Handle tables
        if line.startswith('|'):
            # Collect table rows
            table_rows = []
            while i < len(lines) and lines[i].strip().startswith('|'):
                row_text = lines[i].strip()[1:-1]  # Remove | at start and end
                cells = [c.strip() for c in row_text.split('|')]
                # Skip separator rows and header rows
                if not any('---' in c for c in cells) and not any('Attribute' in c for c in cells):
                    table_rows.append(cells)
                i += 1
            
            if table_rows:
                # Build table with proper formatting
                formatted_rows = []
                for row in table_rows:
                    if len(row) >= 2:
                        attr = re.sub(r'\*\*', '', row[0]).strip()
                        val = re.sub(r'\*\*', '', row[1]).strip()
                        formatted_rows.append([f"<b>{attr}</b>", val])
                
                if formatted_rows:
                    col_widths = [80 * mm, 80 * mm]
                    table = Table(formatted_rows, colWidths=col_widths)
                    table.setStyle(TableStyle([
                        ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
                        ('BACKGROUND', (0, 0), (0, -1), colors.Color(0.9, 0.9, 0.9)),
                        ('PADDING', (0, 0), (-1, -1), 6),
                        ('FONTSIZE', (0, 0), (-1, -1), 11),
                        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
                        ('FONTNAME', (1, 0), (1, -1), 'Helvetica'),
                        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                    ]))
                    elements.append(table)
                    elements.append(Spacer(1, 12))
            continue
        
        # Handle bullet points
        if line.startswith('• ') or line.startswith('- ') or line.startswith('* '):
            bullets = []
            while i < len(lines) and (lines[i].strip().startswith('• ') or 
                                       lines[i].strip().startswith('- ') or 
                                       lines[i].strip().startswith('* ')):
                b = lines[i].strip()[2:].strip()
                # Process bold text
                b = re.sub(r'\*\*([^*]+)\*\*', r'<b>\1</b>', b)
                bullets.append(b)
                i += 1
            
            for b in bullets:
                if b:
                    elements.append(Paragraph(f"• {b}", body))
            elements.append(Spacer(1, 6))
            continue
        
        # Handle bold text lines (standalone bold lines)
        if line.startswith('**') and line.endswith('**'):
            text = re.sub(r'\*\*', '', line)
            elements.append(Paragraph(f"<b>{text}</b>", body))
            elements.append(Spacer(1, 6))
            i += 1
            continue
        
        # Handle regular text
        if line:
            text = re.sub(r'\*\*([^*]+)\*\*', r'<b>\1</b>', line)
            elements.append(Paragraph(text, body))
            elements.append(Spacer(1, 4))
            i += 1
            continue
        
        i += 1
    
    # Add final separator
    elements.extend(make_section_separator())
    
    return elements

def generate_pdf(md_path, pdf_path):
    """Generate PDF from markdown file."""
    
    with open(md_path, 'r', encoding='utf-8') as f:
        md_content = f.read()
    
    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=A4,
        topMargin=TOP_MARGIN,
        bottomMargin=BOTTOM_MARGIN,
        leftMargin=LEFT_MARGIN,
        rightMargin=RIGHT_MARGIN
    )
    
    elements = parse_markdown_to_elements(md_content)
    doc.build(elements)
    
    return pdf_path

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 generate_pdf.py <markdown_file> <output_pdf>")
        sys.exit(1)
    
    md_path = sys.argv[1]
    pdf_path = sys.argv[2]
    
    if not os.path.exists(md_path):
        print(f"Error: Markdown file not found: {md_path}")
        sys.exit(1)
    
    result = generate_pdf(md_path, pdf_path)
    print(f"PDF generated: {result}")


===== SCRIPTS/hardix_workflow.py =====

#!/usr/bin/env python3
"""
Salesforce Flow Documentation with Hardix - Main Workflow Script

Workflow:
1. Get flow-meta.xml (from Google Drive or local folder)
2. Use sfdx-hardis to create .md file
3. Analyze .md file and create Architectural Documentation content
4. Apply formatting and styling
5. Create PDF document
6. Save PDF to specified location
7. Remove temporary .md file

Supports:
- Single XML file
- Multiple XML files in batch
- Google Drive or local filesystem sources
"""

import sys
import os
import re
import json
import subprocess
import tempfile
import shutil
from pathlib import Path

# Try to import reportlab, install if needed
try:
    from reportlab.lib.pagesizes import A4
    from reportlab.lib import colors
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.lib.units import mm
except ImportError:
    print("Installing reportlab...")
    subprocess.run([sys.executable, "-m", "pip", "install", "reportlab", "-q"])
    from reportlab.lib.pagesizes import A4
    from reportlab.lib import colors
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.lib.units import mm

# Page configuration
TOP_MARGIN = 25 * mm
BOTTOM_MARGIN = 25 * mm
LEFT_MARGIN = 20 * mm
RIGHT_MARGIN = 20 * mm

# Typography
BODY_FONT_SIZE = 12
H1_FONT_SIZE = 18
H2_FONT_SIZE = 14
H3_FONT_SIZE = 12

def run_command(cmd, capture=True):
    """Run shell command and return output."""
    if capture:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.stdout, result.stderr, result.returncode
    else:
        result = subprocess.run(cmd, shell=True)
        return "", "", result.returncode

def extract_metadata_from_markdown(md_content):
    """Extract metadata from sfdx-hardis markdown output."""
    metadata = {
        'name': '',
        'type': '',
        'status': '',
        'description': ''
    }
    
    lines = md_content.split('\n')
    for i, line in enumerate(lines):
        # Extract flow name from first H1 heading
        if line.startswith('# '):
            metadata['name'] = line[2:].strip()
        
        # Extract from table
        if '|' in line and not line.startswith('|'):
            cells = [c.strip() for c in line.split('|')]
            if len(cells) >= 2:
                key = cells[0].strip()
                val = cells[1].strip()
                
                if 'Process Type' in key:
                    metadata['type'] = val
                elif 'Label' in key and not metadata['name']:
                    metadata['name'] = val
                elif 'Status' in key:
                    metadata['status'] = val
    
    return metadata

def extract_flow_metadata(xml_path):
    """Extract flow metadata from XML file - FIXED to extract from root element."""
    metadata = {
        'name': '',
        'type': '',
        'trigger': '',
        'record_trigger': '',
        'object': '',
        'status': '',
        'api_version': '',
        'description': ''
    }
    
    try:
        with open(xml_path, 'r') as f:
            content = f.read()
        
        # Extract processType - convert to readable format
        type_match = re.search(r'<processType>([^<]+)</processType>', content)
        if type_match:
            pt = type_match.group(1).strip()
            type_map = {
                'AutoLaunchedFlow': 'Auto Launched Flow',
                'RecordTriggeredFlow': 'Record Triggered Flow',
                'ScreenFlow': 'Screen Flow',
                'Flow': 'Flow',
                'Workflow': 'Workflow',
                'CustomEvent': 'Custom Event Flow',
                'ScheduleTriggeredFlow': 'Scheduled Flow'
            }
            metadata['type'] = type_map.get(pt, pt)
        
        # Extract triggerType
        trigger_match = re.search(r'<triggerType>([^<]+)</triggerType>', content)
        if trigger_match:
            metadata['trigger'] = trigger_match.group(1).strip()
        
        # Extract recordTriggerType
        record_trigger_match = re.search(r'<recordTriggerType>([^<]+)</recordTriggerType>', content)
        if record_trigger_match:
            rt = record_trigger_match.group(1).strip().replace('_', ' ')
            metadata['record_trigger'] = rt
        
        # Extract object (from start element)
        object_match = re.search(r'<object>([^<]+)</object>', content)
        if object_match:
            metadata['object'] = object_match.group(1).strip()
        
        # Extract status
        status_match = re.search(r'<status>([^<]+)</status>', content)
        if status_match:
            metadata['status'] = status_match.group(1).strip()
        
        # Extract apiVersion
        api_match = re.search(r'<apiVersion>([^<]+)</apiVersion>', content)
        if api_match:
            metadata['api_version'] = api_match.group(1).strip()
        
        # Extract description
        desc_match = re.search(r'<description>([^<]+)</description>', content)
        if desc_match:
            metadata['description'] = desc_match.group(1).strip()
        
        # Fallback name from filename if not found
        if not metadata['name']:
            basename = os.path.basename(xml_path)
            metadata['name'] = basename.replace('.flow-meta.xml', '').replace('.xml', '')
        
    except Exception as e:
        print(f"Warning: Error extracting metadata: {e}")
        # Fallback
        metadata['name'] = os.path.basename(xml_path).replace('.flow-meta.xml', '')
    
    return metadata

def extract_all_flow_nodes(xml_path):
    """Extract ALL flow nodes from XML with proper categorization."""
    nodes = {
        'record_lookups': [],
        'record_creates': [],
        'record_updates': [],
        'record_deletes': [],
        'screens': [],
        'decisions': [],
        'assignments': [],
        'actions': [],
        'transforms': [],
        'subflows': [],
        'waits': [],
        'loops': []
    }
    
    try:
        with open(xml_path, 'r') as f:
            content = f.read()
        
        # Record Lookups
        for match in re.finditer(r'<recordLookups[^>]*>(.*?)</recordLookups>', content, re.DOTALL):
            block = match.group(1)
            name = re.search(r'<name>([^<]+)</name>', block)
            label = re.search(r'<label>([^<]+)</label>', block)
            obj = re.search(r'<object>([^<]+)</object>', block)
            if name and label:
                nodes['record_lookups'].append({
                    'name': name.group(1),
                    'label': label.group(1),
                    'object': obj.group(1) if obj else 'Unknown'
                })
        
        # Record Creates
        for match in re.finditer(r'<recordCreates[^>]*>(.*?)</recordCreates>', content, re.DOTALL):
            block = match.group(1)
            name = re.search(r'<name>([^<]+)</name>', block)
            label = re.search(r'<label>([^<]+)</label>', block)
            obj = re.search(r'<object>([^<]+)</object>', block)
            if name and label:
                nodes['record_creates'].append({
                    'name': name.group(1),
                    'label': label.group(1),
                    'object': obj.group(1) if obj else 'Unknown'
                })
        
        # Record Updates
        for match in re.finditer(r'<recordUpdates[^>]*>(.*?)</recordUpdates>', content, re.DOTALL):
            block = match.group(1)
            name = re.search(r'<name>([^<]+)</name>', block)
            label = re.search(r'<label>([^<]+)</label>', block)
            obj = re.search(r'<object>([^<]+)</object>', block)
            if name and label:
                nodes['record_updates'].append({
                    'name': name.group(1),
                    'label': label.group(1),
                    'object': obj.group(1) if obj else 'Unknown'
                })
        
        # Record Deletes
        for match in re.finditer(r'<recordDeletes[^>]*>(.*?)</recordDeletes>', content, re.DOTALL):
            block = match.group(1)
            name = re.search(r'<name>([^<]+)</name>', block)
            label = re.search(r'<label>([^<]+)</label>', block)
            obj = re.search(r'<object>([^<]+)</object>', block)
            if name and label:
                nodes['record_deletes'].append({
                    'name': name.group(1),
                    'label': label.group(1),
                    'object': obj.group(1) if obj else 'Unknown'
                })
        
        # Screens
        for match in re.finditer(r'<screens[^>]*>(.*?)</screens>', content, re.DOTALL):
            block = match.group(1)
            name = re.search(r'<name>([^<]+)</name>', block)
            label = re.search(r'<label>([^<]+)</label>', block)
            if name and label:
                nodes['screens'].append({
                    'name': name.group(1),
                    'label': label.group(1)
                })
        
        # Decisions
        for match in re.finditer(r'<decisions[^>]*>(.*?)</decisions>', content, re.DOTALL):
            block = match.group(1)
            name = re.search(r'<name>([^<]+)</name>', block)
            label = re.search(r'<label>([^<]+)</label>', block)
            if name and label:
                nodes['decisions'].append({
                    'name': name.group(1),
                    'label': label.group(1)
                })
        
        # Assignments
        for match in re.finditer(r'<assignments[^>]*>(.*?)</assignments>', content, re.DOTALL):
            block = match.group(1)
            name = re.search(r'<name>([^<]+)</name>', block)
            label = re.search(r'<label>([^<]+)</label>', block)
            if name and label:
                nodes['assignments'].append({
                    'name': name.group(1),
                    'label': label.group(1)
                })
        
        # Action Calls
        for match in re.finditer(r'<actionCalls[^>]*>(.*?)</actionCalls>', content, re.DOTALL):
            block = match.group(1)
            name = re.search(r'<name>([^<]+)</name>', block)
            label = re.search(r'<label>([^<]+)</label>', block)
            action_name = re.search(r'<actionName>([^<]+)</actionName>', block)
            if name and label:
                nodes['actions'].append({
                    'name': name.group(1),
                    'label': label.group(1),
                    'action_name': action_name.group(1) if action_name else 'Unknown'
                })
        
        # Transforms
        for match in re.finditer(r'<transforms[^>]*>(.*?)</transforms>', content, re.DOTALL):
            block = match.group(1)
            name = re.search(r'<name>([^<]+)</name>', block)
            label = re.search(r'<label>([^<]+)</label>', block)
            if name and label:
                nodes['transforms'].append({
                    'name': name.group(1),
                    'label': label.group(1)
                })
        
        # Subflows
        for match in re.finditer(r'<subflows[^>]*>(.*?)</subflows>', content, re.DOTALL):
            block = match.group(1)
            name = re.search(r'<name>([^<]+)</name>', block)
            label = re.search(r'<label>([^<]+)</label>', block)
            if name and label:
                nodes['subflows'].append({
                    'name': name.group(1),
                    'label': label.group(1)
                })
        
    except Exception as e:
        print(f"Warning: Error extracting nodes: {e}")
    
    return nodes

def get_filename_from_path(xml_path):
    """Extract filename without extension from path."""
    basename = os.path.basename(xml_path)
    return basename.replace('.flow-meta.xml', '').replace('.xml', '')

def generate_architectural_documentation(xml_path, md_content):
    """Generate architectural documentation following the skill template."""
    
    # Extract metadata from XML
    metadata = extract_flow_metadata(xml_path)
    nodes = extract_all_flow_nodes(xml_path)
    
    # If markdown content is available, extract additional metadata from it
    if md_content:
        md_metadata = extract_metadata_from_markdown(md_content)
        if md_metadata.get('name') and md_metadata['name'] != metadata.get('name'):
            metadata['name'] = md_metadata['name']
        if md_metadata.get('type'):
            metadata['type'] = md_metadata['type']
        if md_metadata.get('status'):
            metadata['status'] = md_metadata['status']
    
    # Determine flow type
    if nodes['screens']:
        flow_type = "Screen Flow"
    elif metadata.get('record_trigger'):
        flow_type = "Record Triggered Flow"
    elif metadata.get('trigger'):
        flow_type = "Auto Launched Flow"
    else:
        flow_type = metadata.get('type', 'Flow')
    
    # Build document
    doc = []
    
    # =========================================
    # SECTION 1: OVERVIEW & PURPOSE
    # =========================================
    doc.append("# 1. Overview & Purpose")
    doc.append("")
    doc.append("## Flow Details")
    doc.append("")
    doc.append(f"- Flow Name: {metadata.get('name', 'Unknown')}")
    doc.append(f"- Type: {flow_type}")
    
    if metadata.get('record_trigger'):
        doc.append(f"- Trigger: {metadata.get('record_trigger').replace('_', ' ')}")
    elif metadata.get('trigger'):
        doc.append(f"- Trigger: {metadata.get('trigger')}")
    
    doc.append(f"- Status: {metadata.get('status', 'Active')}")
    doc.append(f"- API Version: {metadata.get('api_version', 'N/A')}")
    doc.append("")
    doc.append("## Purpose")
    doc.append("")
    
    # Simple business summary
    if nodes['screens']:
        doc.append("This is an interactive screen flow that guides users through a series of screens to input data and make decisions.")
    elif nodes['record_creates'] and nodes['record_updates']:
        doc.append("This flow automates the creation and update of records based on business rules.")
    elif nodes['record_creates']:
        doc.append("This flow automates the creation of new records.")
    elif nodes['record_updates']:
        doc.append("This flow automates the update of existing records.")
    else:
        doc.append("This flow performs automated data processing operations.")
    
    doc.append("")
    
    # =========================================
    # SECTION 2: FLOW CHARACTERISTICS
    # =========================================
    doc.append("___")
    doc.append("")
    doc.append("# 2. Flow Characteristics")
    doc.append("")
    doc.append("| Attribute | Value |")
    doc.append("|-----------|-------|")
    
    # Invocation
    if metadata.get('record_trigger'):
        invocation = f"Record Triggered - {metadata.get('record_trigger').replace('_', ' ')}"
    elif nodes['screens']:
        invocation = "Screen Flow (User-Initiated)"
    else:
        invocation = "Auto Launched"
    
    doc.append(f"| Invocation | {invocation} |")
    
    # Input Variable
    if metadata.get('object'):
        input_var = metadata.get('object')
    elif nodes['screens']:
        input_var = "User Input (via Screens)"
    else:
        input_var = "Not Required"
    
    doc.append(f"| Input Variable | {input_var} |")
    
    # Mode
    if nodes['screens']:
        mode = "Synchronous (Interactive)"
    elif metadata.get('record_trigger'):
        mode = "Synchronous (After Save)"
    else:
        mode = "Synchronous"
    
    doc.append(f"| Mode | {mode} |")
    
    # Output
    outputs = []
    if nodes['record_creates']:
        outputs.append("Created Records")
    if nodes['record_updates']:
        outputs.append("Updated Records")
    if nodes['screens']:
        outputs.append("Screen Navigation")
    output_str = ", ".join(outputs) if outputs else "Process Completion"
    doc.append(f"| Output | {output_str} |")
    
    # Navigation
    if nodes['decisions']:
        nav = f"Branch on {len(nodes['decisions'])} decision points"
    else:
        nav = "Sequential Path"
    doc.append(f"| Navigation | {nav} |")
    
    doc.append("")
    
    # =========================================
    # SECTION 3: HIGH-LEVEL PROCESS FLOW
    # =========================================
    doc.append("___")
    doc.append("")
    doc.append("# 3. High-Level Process Flow")
    doc.append("")
    
    step_num = 1
    
    # Build steps with meaningful descriptions
    if nodes['screens']:
        for screen in nodes['screens'][:5]:
            doc.append(f"Step {step_num}: {screen['label']}")
            step_num += 1
    
    if nodes['record_creates']:
        creates = [c['label'] for c in nodes['record_creates'][:3]]
        if creates:
            doc.append(f"Step {step_num}: Create Records ({', '.join(creates)})")
            step_num += 1
    
    if nodes['record_updates']:
        updates = [u['label'] for u in nodes['record_updates'][:3]]
        if updates:
            doc.append(f"Step {step_num}: Update Records ({', '.join(updates)})")
            step_num += 1
    
    if nodes['decisions'] and len(nodes['decisions']) <= 3:
        for decision in nodes['decisions']:
            doc.append(f"Step {step_num}: {decision['label']}")
            step_num += 1
    
    # If still empty, add generic step
    if step_num == 1:
        doc.append("Step 1: Process records according to business rules")
    
    doc.append("")
    
    # =========================================
    # SECTION 4: ARCHITECTURAL SUMMARY
    # =========================================
    doc.append("___")
    doc.append("")
    doc.append("# 4. Architectural Summary")
    doc.append("")
    
    # Simple 4-5 bullet points
    if nodes['record_creates'] and nodes['record_updates']:
        doc.append("• Automates the complete lifecycle of record creation and updates")
    elif nodes['record_creates']:
        doc.append("• Automates the creation of new records in Salesforce")
    elif nodes['record_updates']:
        doc.append("• Automates the update of existing records based on business logic")
    
    if nodes['screens']:
        doc.append("• Provides guided user interface for consistent data entry")
    
    if nodes['decisions']:
        doc.append("• Implements decision-based logic for conditional processing")
    
    if nodes['record_creates'] or nodes['record_updates']:
        doc.append("• Ensures data integrity through declarative operations")
    
    doc.append("• Reduces manual effort and potential for human error")
    doc.append("")
    
    return '\n'.join(doc)


def create_pdf_from_markdown(md_content, pdf_path):
    """Create PDF from markdown content."""
    
    # Styles
    body = ParagraphStyle(
        'Body',
        fontName='Helvetica',
        fontSize=BODY_FONT_SIZE,
        leading=BODY_FONT_SIZE * 1.2,
        spaceAfter=6
    )
    
    h1 = ParagraphStyle(
        'H1',
        fontName='Helvetica-Bold',
        fontSize=H1_FONT_SIZE,
        leading=H1_FONT_SIZE * 1.2,
        spaceAfter=14,
        spaceBefore=0
    )
    
    h2 = ParagraphStyle(
        'H2',
        fontName='Helvetica-Bold',
        fontSize=H2_FONT_SIZE,
        leading=H2_FONT_SIZE * 1.2,
        spaceAfter=11,
        spaceBefore=16
    )
    
    h3 = ParagraphStyle(
        'H3',
        fontName='Helvetica-Bold',
        fontSize=H3_FONT_SIZE,
        leading=H3_FONT_SIZE * 1.2,
        spaceAfter=9,
        spaceBefore=12
    )
    
    elements = []
    lines = md_content.split('\n')
    i = 0
    
    while i < len(lines):
        line = lines[i].strip()
        
        # Skip empty, mermaid, comments
        if not line or line.startswith('```') or line.startswith('%%') or line.startswith('<!--'):
            i += 1
            continue
        
        # Separator
        if line.startswith('---'):
            elements.append(Spacer(1, 18))
            elements.append(Paragraph('_' * 60, body))
            elements.append(Spacer(1, 18))
            i += 1
            continue
        
        # H1
        if line.startswith('# ') and not line.startswith('## '):
            elements.append(Spacer(1, 18))
            text = re.sub(r'^# \d+\.\s*', '', line)
            elements.append(Paragraph(text, h1))
            elements.append(Spacer(1, 8))
            i += 1
            continue
        
        # H2
        if line.startswith('## '):
            elements.append(Paragraph(line[3:], h2))
            i += 1
            continue
        
        # H3
        if line.startswith('### '):
            elements.append(Paragraph(line[4:], h3))
            i += 1
            continue
        
        # Tables
        if line.startswith('|'):
            table_rows = []
            while i < len(lines) and lines[i].strip().startswith('|'):
                row_text = lines[i].strip()[1:-1]
                cells = [c.strip() for c in row_text.split('|')]
                if not any('---' in c for c in cells) and not any('Attribute' in c for c in cells):
                    table_rows.append(cells)
                i += 1
            
            if table_rows:
                formatted = []
                for row in table_rows:
                    if len(row) >= 2:
                        attr = re.sub(r'\*\*', '', row[0]).strip()
                        val = re.sub(r'\*\*', '', row[1]).strip()
                        formatted.append([f"<b>{attr}</b>", val])
                
                if formatted:
                    tbl = Table(formatted, colWidths=[80*mm, 80*mm])
                    tbl.setStyle(TableStyle([
                        ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
                        ('BACKGROUND', (0, 0), (0, -1), colors.Color(0.9, 0.9, 0.9)),
                        ('PADDING', (0, 0), (-1, -1), 6),
                        ('FONTSIZE', (0, 0), (-1, -1), 11),
                        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
                        ('FONTNAME', (1, 0), (1, -1), 'Helvetica'),
                        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                    ]))
                    elements.append(tbl)
                    elements.append(Spacer(1, 12))
            continue
        
        # Bullets
        if line.startswith('• ') or line.startswith('- ') or line.startswith('* '):
            bullets = []
            while i < len(lines) and (lines[i].strip().startswith('• ') or 
                                       lines[i].strip().startswith('- ') or 
                                       lines[i].strip().startswith('* ')):
                b = lines[i].strip()[2:].strip()
                b = re.sub(r'\*\*([^*]+)\*\*', r'<b>\1</b>', b)
                bullets.append(b)
                i += 1
            
            for b in bullets:
                if b:
                    elements.append(Paragraph(f"• {b}", body))
            elements.append(Spacer(1, 6))
            continue
        
        # Regular text
        if line:
            text = re.sub(r'\*\*([^*]+)\*\*', r'<b>\1</b>', line)
            elements.append(Paragraph(text, body))
            elements.append(Spacer(1, 4))
        
        i += 1
    
    # Build PDF
    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=A4,
        topMargin=TOP_MARGIN,
        bottomMargin=BOTTOM_MARGIN,
        leftMargin=LEFT_MARGIN,
        rightMargin=RIGHT_MARGIN
    )
    doc.build(elements)
    
    return pdf_path

def process_single_xml(xml_path, output_dir=None, source_type='local'):
    """Process a single XML file and generate PDF."""
    
    print(f"\nProcessing: {xml_path}")
    
    # Create temp directory for markdown
    temp_dir = tempfile.mkdtemp(prefix="hardix_")
    
    try:
        # Generate markdown using sfdx-hardis
        temp_md = os.path.join(temp_dir, os.path.basename(xml_path).replace('.xml', '.md'))
        
        print(f"  Generating markdown with sfdx-hardis...")
        stdout, stderr, code = run_command(
            f"sfdx hardis:doc:flow2markdown --inputfile '{xml_path}' --outputfile '{temp_md}' --skipauth"
        )
        
        if code != 0:
            print(f"  Warning: sfdx-hardis failed: {stderr}")
            md_content = ""
        else:
            # Read generated markdown
            with open(temp_md, 'r') as f:
                md_content = f.read()
        
        # Generate architectural documentation
        print(f"  Creating architectural documentation...")
        arch_doc = generate_architectural_documentation(xml_path, md_content)
        
        # Use filename-based naming as specified
        flow_name = get_filename_from_path(xml_path)
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)
            pdf_path = os.path.join(output_dir, f"{flow_name}.pdf")
        else:
            pdf_path = os.path.join(os.path.dirname(xml_path), f"{flow_name}.pdf")
        
        print(f"  Generating PDF...")
        create_pdf_from_markdown(arch_doc, pdf_path)
        
        print(f"  ✅ PDF generated: {pdf_path}")
        
        # Clean up temp files
        shutil.rmtree(temp_dir)
        
        return pdf_path
        
    except Exception as e:
        print(f"  Error processing {xml_path}: {e}")
        import traceback
        traceback.print_exc()
        if os.path.exists(temp_dir):
            shutil.rmtree(temp_dir)
        raise

def process_google_drive(folder_id, output_dir=None):
    """Process all XML files from a Google Drive folder."""
    
    print(f"\nSearching Google Drive folder: {folder_id}")
    
    # Search for flow XML files - simplified query
    stdout, _, _ = run_command(
        f"gog drive search '\"{folder_id}\" in parents and name contains \"flow-meta\"' --max 50 --json"
    )
    
    try:
        files = json.loads(stdout).get('files', [])
    except:
        files = []
    
    if not files:
        print("No flow-meta.xml files found in the folder.")
        return []
    
    print(f"Found {len(files)} XML file(s)")
    
    # Create temp directory
    temp_dir = tempfile.mkdtemp(prefix="hardix_gdrive_")
    pdfs = []
    
    for file in files:
        try:
            # Download file
            local_xml = os.path.join(temp_dir, file['name'])
            print(f"\nDownloading: {file['name']}")
            run_command(f"gog drive download {file['id']} --out '{local_xml}'", capture=False)
            
            # Process file
            pdf_path = process_single_xml(local_xml, output_dir, 'google_drive')
            pdfs.append(pdf_path)
            
        except Exception as e:
            print(f"  Error processing {file['name']}: {e}")
    
    # Clean up
    shutil.rmtree(temp_dir)
    
    return pdfs

def upload_to_google_drive(pdf_paths, folder_id):
    """Upload PDF files to Google Drive."""
    
    print(f"\nUploading {len(pdf_paths)} file(s) to Google Drive...")
    
    for pdf_path in pdf_paths:
        if os.path.exists(pdf_path):
            pdf_name = os.path.basename(pdf_path)
            print(f"  Uploading: {pdf_name}")
            run_command(f"gog drive upload '{pdf_path}' --parent {folder_id}", capture=False)
            print(f"  ✅ Uploaded: {pdf_name}")

def main():
    if len(sys.argv) < 2:
        print("""
Salesforce Flow Documentation with Hardix
=========================================

Usage:
    python3 hardix_workflow.py <source> [options]

Sources:
    <xml_file>                           - Single XML file path
    --gdrive <folder_id>                 - Google Drive folder ID
    --local <folder_path>                 - Local folder with XML files

Options:
    --output <folder_path>               - Output folder for PDFs (default: same as XML)
    --upload <folder_id>                  - Upload PDFs to Google Drive folder

Examples:
    # Single file
    python3 hardix_workflow.py /path/to/Account_Update.flow-meta.xml
    
    # Google Drive folder
    python3 hardix_workflow.py --gdrive 1NbUG8Vcm9IZCgE_4o5tcsx03AWxUS6Qn
    
    # Local folder
    python3 hardix_workflow.py --local /path/to/flows/
    
    # With output folder
    python3 hardix_workflow.py /path/to/Account_Update.flow-meta.xml --output /tmp/docs/
    
    # With Google Drive upload
    python3 hardix_workflow.py /path/to/Account_Update.flow-meta.xml --upload 1NbUG8Vcm9IZCgE_4o5tcsx03AWxUS6Qn
""")
        sys.exit(1)
    
    source = sys.argv[1]
    output_dir = None
    upload_folder = None
    gdrive_folder = None
    local_folder = None
    
    # Parse arguments - check for source flags first
    if source == '--gdrive' and len(sys.argv) > 2:
        gdrive_folder = sys.argv[2]
        i = 3
    elif source == '--local' and len(sys.argv) > 2:
        local_folder = sys.argv[2]
        i = 3
    else:
        i = 2
    
    # Parse remaining arguments
    while i < len(sys.argv):
        if sys.argv[i] == '--output' and i + 1 < len(sys.argv):
            output_dir = sys.argv[i + 1]
            i += 2
        elif sys.argv[i] == '--upload' and i + 1 < len(sys.argv):
            upload_folder = sys.argv[i + 1]
            i += 2
        elif sys.argv[i] == '--gdrive' and i + 1 < len(sys.argv):
            gdrive_folder = sys.argv[i + 1]
            i += 2
        elif sys.argv[i] == '--local' and i + 1 < len(sys.argv):
            local_folder = sys.argv[i + 1]
            i += 2
        else:
            i += 1
    
    pdfs = []
    
    # Process based on source type
    if source == '--gdrive' and gdrive_folder:
        pdfs = process_google_drive(gdrive_folder, output_dir)
    elif source == '--local' and local_folder:
        # Process all XML files in folder
        for xml_file in Path(local_folder).glob('*.flow-meta.xml'):
            try:
                pdf_path = process_single_xml(str(xml_file), output_dir, 'local')
                pdfs.append(pdf_path)
            except Exception as e:
                print(f"Error: {e}")
    elif os.path.isfile(source):
        # Single file
        pdf_path = process_single_xml(source, output_dir, 'local')
        pdfs.append(pdf_path)
    elif os.path.isdir(source):
        # Folder path
        for xml_file in Path(source).glob('*.flow-meta.xml'):
            try:
                pdf_path = process_single_xml(str(xml_file), output_dir, 'local')
                pdfs.append(pdf_path)
            except Exception as e:
                print(f"Error: {e}")
    else:
        print(f"Error: Source not found: {source}")
        sys.exit(1)
    
    # Upload to Google Drive if requested
    if upload_folder and pdfs:
        upload_to_google_drive(pdfs, upload_folder)
    
    print(f"\n{'='*50}")
    print(f"Processing complete! Generated {len(pdfs)} PDF(s)")
    for pdf in pdfs:
        print(f"  - {pdf}")

if __name__ == "__main__":
    main()

---

## Step N — end telemetry (REQUIRED, LAST STEP — even on failure)

On success:

```
telemetry.skill_end({
  invocation_id: "<saved id>",
  status: "success",
  output_summary: "<short, non-sensitive summary of what was produced>"
})
```

On any error / exception / abort:

```
telemetry.skill_end({
  invocation_id: "<saved id>",
  status: "error",
  error_message: "<one-line cause>"
})
```

## Authoring rules

- **Do not** put PII, secrets, or full file contents in `input_summary` /
  `output_summary` / `error_message`. The gateway hashes these fields, but you
  should still treat them as if they were public.
- **Do not** skip `skill_end` because the skill is "fast" or "simple" — open
  spans without an end leak memory in the MCP process and break duration
  metrics.
- **Do not** call `skill_start` more than once per invocation. If your skill
  delegates to subskills, those subskills run their own start/end pair.
