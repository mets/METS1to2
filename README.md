# METS 1 to METS 2 XSL transformation

Transforms METS 1 to METS 2 beta schema.

See other [METS schema resources](https://github.com/mets/METS-schema)
     
## Version 0.2 (2023-01-23)
     
- flattens nested filegroups
- migrates XPTR attribute to LOCREF
- XSLT 1.0 implementation for maximum compatibility
- removes unused namespace declarations
- handle alternate xlink namespace (not valid in current version of METS schema, but shows up in some METS profiles, and not difficult to handle) 
     
## Version 0.1 (2022-12-22)
     
- adds METS2 schema
- changes namespace of METS1 elements to METS2
- puts dmdSec, amdSec, techMD, rightsMD, sourceMD, digiprovMD into mdGrp sections and md elements
- changes xlink:href to LOCREF and warns on usage of other xlink attributes
- maps OTHER attributes to their non-OTHER versions (and warn if this would mask a non-OTHER original attribute) 
- wraps structMaps in structSec element
- gives an error if structLink, behaviorSec, XPTR, or nested filegroups are used
- keeps all other elements & attributes as-is
     
## Known issues:

- Doesn't remove the old XSD from xsi:schemaLocation
- The message regarding nested fileGrp elements could be more useful.
- Namespace declarations get pushed down to xmlData nodes - if you want other namespaces (e.g. PREMIS) to appear at the top level,
 add them to the namespace declarations in the xsl:stylesheet above, matching prefixes in the input document.

