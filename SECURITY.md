# Security

RuleLens executes trusted application-owned Ruby policy code in the process where you capture results. It is not a sandbox. Use controlled development/test environments and side-effect-free setup and policies.

Captures omit input objects and exception messages, but labels, identifiers and metadata are supplied by your application and may still contain sensitive information. Review artifacts before sharing them. Do not commit real captures, credentials or production data.

Reports escape captured text and do not require JavaScript or remote assets. A passing comparison covers only the supplied cases. It is not a security audit or a proof that authorization is correct.

For a suspected vulnerability, use GitHub's private vulnerability reporting if available. If it is unavailable, open an issue requesting a private contact method without including an exploit, secret or sensitive record. No dedicated security response SLA is offered for this early MVP.
