# Entity Templates

Use these templates when creating entity files in `.memory/entities/`.

## Company Template

File: `.memory/entities/companies/{slug}.md`

```markdown
# {Company Name}

## Overview
{1-2 sentence description}

## Key Facts
- **Website**: {url}
- **Category**: {industry/category}
- **Size**: {employee count or range}
- **Founded**: {year}
- **Funding**: {total raised or stage}

## Relevance to Xerus
- **Score**: {1-10}
- **Why**: {why this company matters to us}
- **Relationship**: {prospect | competitor | partner | inspiration}

## Research History
| Date | Agent | Skill | Key Finding |
|------|-------|-------|-------------|

## Notes
{Freeform observations}

## Backlinks
- [[related-entity-1]]
- [[related-entity-2]]

## DB References
- prospects: id={N} or competitors: id={N}
- entity_registry: id={N}
```

## Person Template

File: `.memory/entities/people/{slug}.md`

```markdown
# {Person Name}

## Overview
- **Role**: {title}
- **Affiliation**: [[{company-slug}]]
- **Platforms**: {twitter handle, linkedin, etc.}

## Relevance
- **Score**: {1-10}
- **Why**: {why this person matters}
- **Type**: {influencer | founder | investor | journalist | user}

## Interactions
| Date | Channel | Context |
|------|---------|---------|

## Notes
{Freeform observations}

## Backlinks
- [[related-entity-1]]
- [[related-entity-2]]

## DB References
- prospects: id={N}
- entity_registry: id={N}
```

## Topic Template

File: `.memory/entities/topics/{slug}.md`

```markdown
# {Topic Name}

## Description
{What this topic is about}

## Trend
- **Direction**: {rising | stable | declining}
- **Relevance**: {1-10}
- **First tracked**: {date}

## Research History
| Date | Agent | Skill | Key Finding |
|------|-------|-------|-------------|

## Related Content
| Date | Channel | Content | Status |
|------|---------|---------|--------|

## Backlinks
- [[related-entity-1]]
- [[related-entity-2]]

## DB References
- topics: id={N}
- entity_registry: id={N}
```

## Product Template

File: `.memory/entities/products/{slug}.md`

```markdown
# {Product Name}

## Overview
- **Company**: [[{company-slug}]]
- **Category**: {category}
- **Website**: {url}

## Features
{Key features list}

## Pricing
{Pricing model and tiers}

## Comparison to Xerus
| Aspect | {Product} | Xerus |
|--------|-----------|-------|

## Notes
{Freeform observations}

## Backlinks
- [[related-entity-1]]
- [[related-entity-2]]

## DB References
- competitors: id={N} (if competitor)
- entity_registry: id={N}
```
