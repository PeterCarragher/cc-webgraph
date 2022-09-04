/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2022 Common Crawl and contributors
 */
package org.commoncrawl.webgraph;

import java.io.IOException;
import java.io.PrintStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.TreeMap;
import java.util.function.Consumer;
import java.util.function.Function;
import java.util.regex.Pattern;
import java.util.stream.Stream;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import crawlercommons.domains.EffectiveTldFinder;
import it.unimi.dsi.fastutil.Arrays;
import it.unimi.dsi.fastutil.BigArrays;
import it.unimi.dsi.fastutil.longs.LongBigArrays;

/**
 * Convert host-level webgraph to domain-level webgraph. A webgraph is
 * represented by two text files/streams with tab-separated columns
 * <dl>
 * <dt>vertices</dt>
 * <dd>&langle;id, revName&rangle;</dd>
 * <dt>edges</dt>
 * <dd>&langle;fromId, toId&rangle;</dd>
 * </dl>
 * Host or domain names are reversed (<code>www.example.com</code> is written as
 * <code>com.example.www</code>). The vertices file is sorted lexicographically
 * by host name in
 * <a href="https://en.wikipedia.org/wiki/Reverse_domain_name_notation">reverse
 * domain name notation</a>. IDs (0,1,...,n) are assigned in this sort order.
 * The edges file is sorted numerically first by fromId, second by toId. These
 * sorting restrictions allow to convert large host graphs with acceptable
 * memory requirements (number of hosts &times; 4 bytes plus some memory to
 * queue domains unless all hosts under this domain are processed).
 * 
 * Notes, assumptions and preconditions:
 * <ul>
 * <li>host nodes must be sorted lexicographically by reversed host name, see
 * above</li>
 * <li>the host-domain map is hold as array. To overcome Java's max array size
 * (approx. 2^32), {@link HostToDomainGraphBig} (based on fastutils'
 * {@link BigArrays}) is automatically used if the array size limit is hit.</li>
 * <li>the number of resulting domains is limited by Java's max. array size.
 * This shouldn't be a problem.</li>
 * <li>also the number of hosts per domain is limited by Java's max. array
 * size</li>
 * </ul>
 */
public class HostToDomainGraph {

	protected static Logger LOG = LoggerFactory.getLogger(HostToDomainGraph.class);

	protected boolean countHosts = false;
	protected boolean privateDomains = false;
	protected boolean strictDomainValidate = true;

	protected long maxSize;
	private int[] ids;
	protected long currentId = -1;
	protected long lastFromId = -1;
	protected long lastToId = -1;
	private long numInputLinesNodes = 0;
	protected String lastRevHost = null;
	protected Domain lastDomain = null;
	private TreeMap<String, Domain> domainQueue = new TreeMap<>();
	private int maxQueueUsed = 0;

	private static Pattern SPLIT_HOST_PATTERN = Pattern.compile("\\.");

	/**
	 * Representation of a domain as a result of folding one or more host names to a
	 * domain name. Holds all information for the given domain to convert host
	 * vertices and associated edges into a domain graph.
	 */
	protected static class Domain implements Comparable<Domain> {
		final static char HYPHEN = '-';
		final static char DOT = '.';
		String name;
		String revName;
		long id;
		long numberOfHosts;
		List<Long> ids = new ArrayList<>();

		public Domain(String name, String revName, long id, long numberOfHosts) {
			this.name = name;
			this.revName = revName;
			this.id = id;
			this.numberOfHosts = numberOfHosts;
		}

		public Domain(String name, long id, long numberOfHosts) {
			this(name, reverseHost(name), id, numberOfHosts);
		}

		public Domain(String name) {
			this(name, -1, 0);
		}

		public Domain(String name, String revName) {
			this(name, revName, -1, 0);
		}

		public Domain(String name, long hostId) {
			this(name, -1, 0);
			add(hostId);
		}

		public void add(long hostId) {
			ids.add(hostId);
			numberOfHosts++;
		}

		@Override
		public String toString() {
			return name;
		}

		@Override
		public int compareTo(Domain o) {
			return revName.compareTo(o.revName);
		}

		/**
		 * Whether the domain is safe to output given the reversed domain name seen
		 * next.
		 */
		public boolean isSafeToOutput(String nextDomainRevName) {
			return isSafeToOutput(this.revName, nextDomainRevName);
		}

		public static boolean isSafeToOutput(String domainRevName, String nextDomainRevName) {
			return compareRevDomainsSafe(domainRevName, nextDomainRevName) < 0;
		}

		public static int compareRevDomainsSafe(String d1, String d2) {
			int l1 = d1.length();
			int l2 = d2.length();
			int l = Math.min(l1, l2);
			for (int i = 0; i < l; i++) {
				char c1 = d1.charAt(i);
				char c2 = d2.charAt(i);
				if (c1 != c2) {
					return c1 - c2;
				} else if (c1 == HYPHEN) {
					/*
					 * cannot finish "org.example-domain" unless "org.example" is done
					 */
					return 0;
				}
			}
			if (l1 == l2) {
				return 0;
			}
			if (l1 > l2) {
				char c1 = d1.charAt(l2);
				switch (c1) {
				case HYPHEN:
					/*
					 * cannot finish "org.example-domain" unless "org.example" is done
					 */
				case DOT:
					// cannot finish "tld.suffix.suffix2.domain" unless "tld.suffix" is done
					return 1;
				}
				return c1 - DOT;
			}
			char c2 = d2.charAt(l1);
			if (c2 == HYPHEN || c2 == DOT)
				return 1;
			return DOT - c2;
		}
	}

	private HostToDomainGraph() {
	}

	public HostToDomainGraph(int maxSize) {
		this.maxSize = maxSize;
		ids = new int[maxSize];
	}

	public void doCount(boolean countHosts) {
		this.countHosts = countHosts;
	}

	public void doPrivateDomains(boolean privateDomains) {
		this.privateDomains = privateDomains;
	}

	public void setStrictDomainValidate(boolean strict) {
		this.strictDomainValidate = strict;
	}

	public static String reverseHost(String revHost) {
		String[] rev = SPLIT_HOST_PATTERN.split(revHost);
		for (int i = 0; i < (rev.length / 2); i++) {
			String temp = rev[i];
			rev[i] = rev[rev.length - i - 1];
			rev[rev.length - i - 1] = temp;
		}
		return String.join(".", rev);
	}

	protected void setValue(long id, long value) {
		ids[(int) id] = (int) value;
	}

	protected long getValue(long id) {
		return ids[(int) id];
	}

	public String convertNode(String line) {
		numInputLinesNodes++;
		int sep = line.indexOf('\t');
		if (sep == -1) {
			LOG.warn("Skipping invalid line: <{}>", line);
			return "";
		}
		long id = Long.parseLong(line.substring(0, sep));
		String revHost = line.substring(sep + 1);
		if (lastRevHost != null) {
			if (lastRevHost.compareTo(revHost) >= 0) {
				String msg = "Reversed host names in input are not properly sorted: " + lastRevHost + " <> " + revHost;
				LOG.error(msg);
				throw new RuntimeException(msg);
			}
		}
		lastRevHost = revHost;
		String host = reverseHost(revHost);
		String domain = EffectiveTldFinder.getAssignedDomain(host, true, !privateDomains);
		StringBuilder sb = new StringBuilder();
		if (domain == null && !strictDomainValidate) {
			if (EffectiveTldFinder.getEffectiveTLDs().containsKey(host) && host.indexOf('.') != -1) {
				LOG.info("Accepting public suffix {} (containing dot) as domain", host);
			}
			domain = host;
		}
		if (domain == null) {
			LOG.warn("No domain for host: {}", host);
			setValue(id, -1);
			return null;
		}
		if (lastDomain != null && domain.equals(lastDomain.name)) {
			// short cut for the common case many subsequent subdomains of the same domain
			lastDomain.add(id);
			return null;
		}
		lastDomain = queueDomain(sb, domain);
		if (lastDomain != null) {
			lastDomain.add(id);
		}
		if (sb.length() == 0) {
			return null;
		}
		return sb.toString();
	}

	/**
	 * Add the domain name to the queue if it is not already queued. Flush the
	 * queue, assuming properly sorted input.
	 * 
	 * @param sb         domains which are safe to print are added to this
	 *                   StringBuilder.
	 * @param domainName domain name to be queued
	 * @return the queued domain object
	 */
	private Domain queueDomain(StringBuilder sb, String domainName) {
		String revDomainName = reverseHost(domainName);
		Domain domain = null;
		// first, poll all queued domains safe to output
		while (!domainQueue.isEmpty()) {
			String firstDomain = domainQueue.firstKey();
			if (!Domain.isSafeToOutput(firstDomain, revDomainName)) {
				/*
				 * queued domains are sorted lexicographically: if the first/current domain
				 * cannot be safely dequeued and written to output, this is also the case for
				 * the following ones.
				 */
				break;
			}
			Domain d = domainQueue.pollFirstEntry().getValue();
			d.id = ++currentId;
			getNodeLine(sb, d);
		}
		if (domainQueue.containsKey(revDomainName)) {
			domain = domainQueue.get(revDomainName);
		} else {
			domain = new Domain(domainName);
			domainQueue.put(revDomainName, domain);
			if (domainQueue.size() > maxQueueUsed) {
				maxQueueUsed = domainQueue.size();
			}
		}
		return domain;
	}

	private String getNodeLine(Domain domain) {
		StringBuilder b = new StringBuilder();
		getNodeLine(b, domain);
		return b.toString();
	}

	private void getNodeLine(StringBuilder b, Domain domain) {
		if (domain == null)
			return;
		if (domain.id >= 0 && domain.name != null) {
			if (b.length() > 0) {
				b.append('\n');
			}
			b.append(domain.id);
			b.append('\t');
			b.append(reverseHost(domain.name));
			if (countHosts) {
				b.append('\t');
				b.append(domain.numberOfHosts);
			}
		}
		for (Long hostId : domain.ids) {
			setValue(hostId.longValue(), domain.id);
		}
	}

	public String convertEdge(String line) {
		int sep = line.indexOf('\t');
		if (sep == -1) {
			return "";
		}
		long fromId = Long.parseLong(line.substring(0, sep));
		long toId = Long.parseLong(line.substring(sep + 1));
		fromId = getValue(fromId);
		toId = getValue(toId);
		if (fromId == toId || fromId == -1 || toId == -1 || (lastFromId == fromId && lastToId == toId)) {
			return null;
		}
		lastFromId = fromId;
		lastToId = toId;
		return fromId + "\t" + toId;
	}

	public void convert(Function<String, String> func, Stream<String> in, PrintStream out) {
		in.map(func).filter(Objects::nonNull).forEach(out::println);
	}

	public void convert(Function<String, String> func, Stream<String> in, PrintStream out,
			Consumer<? super String> reporter) {
		convert(func, in.peek(reporter), out);
	}

	public void finishNodes(PrintStream out) {
		for (Domain domain : domainQueue.values()) {
			domain.id = ++currentId;
			out.println(getNodeLine(domain));
		}
		domainQueue.clear();
		LOG.info("Number of input lines: {}", numInputLinesNodes);
		LOG.info("Number of domain nodes: {}", currentId + 1);
		LOG.info("Max. domain queue usage: {}", maxQueueUsed);
	}

	public static class HostToDomainGraphBig extends HostToDomainGraph {

		private long[][] ids;

		public HostToDomainGraphBig(long maxSize) {
			this.maxSize = maxSize;
			ids = LongBigArrays.newBigArray(maxSize);
		}

		protected void setValue(long id, long value) {
			BigArrays.set(ids, id, value);
		}

		protected long getValue(long id) {
			return BigArrays.get(ids, id);
		}
	}

	private static void showHelp() {
		System.err.println("HostToDomainGraph [-c] <maxSize> <nodes_in> <nodes_out> <edges_in> <edges_out>");
		System.err.println("Options:");
		System.err.println(" -c\tcount hosts per domain (additional column in <nodes_out>");
		System.err.println(" --private\tconvert to private domains (from the private section of the public");
		System.err.println("          \tsuffix list, see https://publicsuffix.org/list/#list-format");
		System.err.println(" --no-strict-domain-validate\tstrictly discard potentially invalid domains");
	}

	public static void main(String[] args) {
		boolean countHosts = false;
		boolean noStrictDomainValidate = false;
		int argpos = 0;
		while (argpos < args.length && args[argpos].startsWith("-")) {
			switch (args[argpos]) {
			case "-c":
				countHosts = true;
				break;
			case "--no-strict-domain-validate":
				noStrictDomainValidate = true;
				break;
			default:
				System.err.println("Unknown option " + args[argpos]);
				showHelp();
				System.exit(1);
			}
			argpos++;
		}
		if ((args.length - argpos) < 5) {
			showHelp();
			System.exit(1);
		}
		long maxSize = 0;
		try {
			maxSize = Long.parseLong(args[argpos + 0]);
		} catch (NumberFormatException e) {
			LOG.error("Invalid number: " + args[argpos + 0]);
			System.exit(1);
		}
		HostToDomainGraph converter;
		if (maxSize <= Arrays.MAX_ARRAY_SIZE) {
			converter = new HostToDomainGraph((int) maxSize);
		} else {
			converter = new HostToDomainGraphBig(maxSize);
		}
		converter.doCount(countHosts);
		converter.setStrictDomainValidate(!noStrictDomainValidate);
		String nodesIn = args[argpos + 1];
		String nodesOut = args[argpos + 2];
		try (Stream<String> in = Files.lines(Paths.get(nodesIn));
				PrintStream out = new PrintStream(Files.newOutputStream(Paths.get(nodesOut)))) {
			converter.convert(converter::convertNode, in, out);
			converter.finishNodes(out);
			LOG.info("Finished conversion of nodes/vertices");
		} catch (IOException e) {
			LOG.error("Failed to read nodes from " + nodesIn);
			System.exit(1);
		}
		String edgesIn = args[argpos + 3];
		String edgesOut = args[argpos + 4];
		try (Stream<String> in = Files.lines(Paths.get(edgesIn));
				PrintStream out = new PrintStream(Files.newOutputStream(Paths.get(edgesOut)))) {
			converter.convert(converter::convertEdge, in, out);
			LOG.info("Finished conversion of edges");
		} catch (IOException e) {
			LOG.error("Failed to read edges from " + edgesIn);
			System.exit(1);
		}
	}

}
