package Tree::FP;
# Developer : Martin Paczynski <nitram@cpan.org>
# Copyright (c) 2003 Martin Paczynski.  All rights reserved.
# This package is free software and is provided "as is" without express or
# implied warranty.  It may be used, redistributed and/or modified under the
# same terms as Perl itself.


$VERSION = '0.01';
# Whenever version number is increased, check for version in code comments. e.g. if current version is 0.5 going to 0.6,
# search for 'v 0.5' within this document

use Exporter;
@ISA=(Exporter);
@EXPORT=qw();
@EXPORT_OK=qw(combinations);
use strict;
use POSIX;



# FP-Tree Constructor
# Note: default support and confidence level is 10%, they can be set using the setter methods (see below)
# Parameters:
# 	List of items to be stored in header table, in descending order of frequency in the transactional DB being mined.
# 	Example:
# 		Given the following
# 			Item | Count
# 			------------
# 			itm1 | 2
# 			itm2 | 4
# 			itm3 | 3
# 			itm4 | 5
# 			itm5 | 3
# 		The code for creating a new FP-Tree would be
# 		$fptree = Tree::FP->new(itm4,itm2,itm3,itm5,itm1);
# Returns
#	A Tree::FP if successful, undef otherwise.
sub new
	{
	my $class = shift;
	
	unless(@_)
		{
		return undef;
		}
	
	my %header_table;
	my $count = 0;
	
	# Create header nodes from each of the items passed
	while(my $item_name = shift)
		{
		# If a new FP_Tree_header_node cannot be constructed, the FP_Tree cannot be constructed correctly.
		unless($header_table{$item_name} = FP_Tree_header_node->new($item_name,++$count))
			{
			return undef;
			}
		}

	my $self = {
				header_table => \%header_table, 
				root => FP_Tree_node->new,	# The root is a standard FP-Tree node except its item field is blank
				lowest_rank => $count,		# Rank of the lowest ranking item in header table
				patterns => {}, 			# Hash (ref) that will contain all patterns of the tree
				max_pattern_len => 0,		# The longest pattern found in the tree (initially zero)
				support => 0.1, 			# Percent support..
				confidence => 0.1,			# and confidence are expressed as decimal values
				total_transactions => 0, 	# Total transactions loaded into the FP-Tree
				err => '',					# Error string
				};
	
	bless $self, $class;		
	}
	
# Function resets the tree to be allow it to be remined at a different support level
sub reset_tree
	{
	my $self = shift;
	
	# Delete all patterns
	$self->{patterns} = {};
	
	1;
	}	
	
# Return FP-Tree pattern hash ref.
sub patterns
	{
	my $self = shift;
	$self->{patterns};
	}
	
# Return the root of the FP-Tree
sub root
	{
	my $self = shift;
	$self->{root};
	}
	
# Insert new transaction into FP-Tree
# Parameters
# 	List items that appeared in transaction
# The items need not be sorted in any way as the function sorts them before further processing.
# Also, the list can contain duplicates, as these will be removed before further processing.
# If function returns 0, something went wrong with during insertion, check 'FP-Tree'->err for error message.
sub insert_tree
	{
	my $self = shift;

	# If no items passed, nothing to insert.	
	if($#_<0)
		{
		$self->{err} = "'insert_tree' called with null transaction.";
		return 0;
		}
	
	# Strip duplicates from input.
	my %unique = map {$_,1} @_;
	my @items = keys %unique;

	# For each item, see if it was found in header table. If not, FP-Tree not constructed correctly OR
	# there was an error with items being passed to function. In either case, exit.
	for(my $a=0; $a <= $#items; $a++)
		{
		unless(grep {$_ eq $items[$a]} (keys %{$self->{header_table}}))
			{
			$self->{err} = "Item '" . $items[$a] . "' not found in Header Table.";
			return 0;
			}
		}

	# Sort items by L order.
	@items = sort {$self->{header_table}->{$a} <=>  $self->{header_table}->{$b}} @items;	

	
	# Call _tree_insert on the root node of FP_Tree. It should return a positive integer
	# if insertion was successful.
	if(_tree_insert($self,$self->root,@items))
		{
		# Increment the number of transactions.
		$self->{total_transactions}++;
		return 1;
		}
	else
		{
		return 0;
		}
	}
	
	
sub _tree_insert
	{
	my $self = shift;
	my $node = shift;
	
	my $item = shift;
		
	unless($item)
		{
		return 0;
		}	
			
	my $next_node;
	
	# If the current node has a child with label $item...
	if($next_node = $node->child_exists($item))
		{
		#... Then increment the count of this child node.
		$next_node->inc_count;
		}
	else
		{
		#... Otherwise:			
		# Set $next_node to be the new child node with label $item
		$next_node = $node->add_child($item);
		
		# Starting at the header table node with label $item, find the node whose sibling is null
		my $sib_ptr = $self->{header_table}->{$item};
		while(ref $sib_ptr->{sibling})
			{
			$sib_ptr = $sib_ptr->{sibling};
			}
		# Set the pointer to the sibling of this node to be the $next_node.
		$sib_ptr->{sibling} = $next_node;	
		}
	
	# Increase the count of $item field in header table.
	$self->{header_table}->{$item}->inc_count;
	
	# Recursively call _tree_insert, until all items have been added to the FP-Tree.
	1 + _tree_insert($self,$next_node,@_);
	}
	
	
# Given a set and a subset of this set, function returns the complement subset.
# Parameters:
# 	1. Array ref constituting a set
# 	2. Array ref constituting subset
# Return:
# 	Array with complement subset of set (1.)
sub complement
	{
	my %all = map {$_,1} @{+shift};
	grep {!$all{$_}} @{+shift};
	}
	
# Returns confidence set for FP-Tree.
sub confidence
	{
	my $self = shift;
	$self->{confidence};
	}	

# Returns support set for FP-Tree.
sub support
	{
	my $self = shift;
	$self->{support};
	}	

# Sets confidence of FP-Tree.
# Parameters:
#  1. Decimal corresponding to appropriate confidence level (e.g. 0.1 for 10%, 0.01 for 1%)
sub set_confidence
	{
	my $self = shift;
	my $confidence = shift;
	
	if($confidence <= 0)
		{
		$self->{err} = "Confidence must be a positive value [ $confidence ].";
		return 0;
		}
	elsif($confidence > 1)
		{
		$self->{err} = "Confidence cannot exceed 100% (expressed as a decimal) [ $confidence ].";
		return 0;
		}
	
	$self->{confidence} = $confidence;
	}	

# Sets support of FP-Tree.
# Parameters:
#  1. Decimal corresponding to appropriate support level (e.g. 0.1 for 10%, 0.01 for 1%)
sub set_support
	{
	my $self = shift;
	my $support = shift;
	
	if($support <= 0)
		{
		$self->{err} = "Support must be a positive value [ $support ].";
		return 0;
		}
	elsif($support > 1)
		{
		$self->{err} = "Support cannot exceed 100% (expressed as a decimal) [ $support ].";
		return 0;
		}
	
	$self->{support} = $support;
	}	
	
# Returns latest error message for FP-Tree.
sub err
	{
	my $self = shift;
	$self->{err}
	}
	
	
# Function mines associate rules of FP-Tree for given support (and confidence) level.
# Parameters:
# 	None
# Function returns array of FP_Tree_association_rules.
# Each FP_Tree_association_rule contains the following methods, returning corresponding values
#	left
#	right
#	support
#	confidence
# 'left' and 'right' correspond to the left and right side of association rule.
# Example: 	If ham and cheese then bread
# ham and cheese are the left side, and bread is the right side.
# Both 'left' and 'right' are refs to arrays containing individual item labels.
sub association_rules
	{
	my $self = shift;
	
	# First call sub fp_growth, to extract the frequent patterns. This is a slight modification of FPGROWTH algorithm.
	unless($self->fp_growth)
		{
		return ();
		}
	
	# Collect the maximal length frequent patterns (MLFP)
	my @freq_patterns = grep {ref && scalar(@{$_->{pattern}}) == $self->{max_pattern_len}} %{$self->{patterns}};
	
	my @association_rules;

	# Loop through all the MLFPs
	for(my $c=0; $c <= $#freq_patterns; $c++)
		{
		
		# Populate array with all combinations of MLFP
		my @all_combos = @{&combinations(@{$freq_patterns[$c]->{pattern}})};
		
		# Convert base pattern to a string
		my $base_pat_str = join '~', @{$freq_patterns[$c]->{pattern}};

		# Get the support count for the base pattern
		my $support_count = $self->{patterns}->{$base_pat_str}->{count};
		
		# Convert support count to %
		my $support = $support_count/$self->{total_transactions};
		
		# For each sub pattern...
		for(my $d=0;$d <= $#all_combos; $d++)
			{
			# Get the complement
			my @compliment_arr = &complement($all_combos[$d],$freq_patterns[$c]->{pattern});
			
			# If complement empty, this is the base pattern so go to next sub pattern.
			unless(@compliment_arr)
				{
				next;
				}
				
			# Convert the complement array into string
			my $left_str = join '~', @{$all_combos[$d]};
				
			# Compute confidence for association						
			my $confidence = $support_count /  $self->{patterns}->{$left_str}->{count};	

			# Push new association rule onto @association_rules.
			push @association_rules, FP_Tree_association_rule->new($all_combos[$d], \@compliment_arr, $support, $confidence);				
			}
		}

	# Sort association rules in descending of confidence. (For those that have not see an sort of this sort it is
	# a Schwartzian Transformation named after Randal L. Schwartz. Substantial savings in computational time.)
	@association_rules = map $_->[0], sort {$b->[1] <=> $a->[1]} map [$_, $_->confidence], @association_rules;		
	}
	
# Function uses modified FPGROWTH algorithm to find Maximal Length Frequent Patterns (MLFPs)
# The input is the FP-Tree itself.
# Returns 1 if any pattern was found, 0 if no pattern of minimal support count was found or error occured
sub fp_growth
	{
	my $self = shift;
	# Support count must be a whole number therefore, round up the for support count.
	my $support_count = POSIX::ceil $self->{total_transactions}*$self->{support};
	
	my @all_items;
	my $check_count = 0;
	
	# For each item in the header table...
	foreach my $key (keys %{$self->{header_table}})
		{
		# check that each header node is actually initialized
		unless($self->{header_table}->{$key}->count)
			{
			$self->{err} = "Header table node '$key' has no count.";
			return 0;
			}
		
		# check the count. If it is less then the support count needed, move on to the next node.
		if($self->{header_table}->{$key}->count < $support_count)
			{
			next;
			}
		
		# Set the rank-1 element of all_items array to the appropriate header node
		$all_items[$self->{header_table}->{$key}->rank - 1] = $self->{header_table}->{$key};
		
		# Add the single item pttern to the patterns hash of the FP-Tree.
		$self->{patterns}->{$key} = {count => $self->{header_table}->{$key}->count, pattern => [$key]};
		} 
	
	# If there are no items in the all_items array, then there is not even a single item length pattern that
	# meets support criteria, therefore return 0.
	unless(@all_items)
		{
		$self->{err} = "No patterns with minimum support of " . $self->{support} . " found.";
		return 0;
		}
	
	
	# In descending order, loop through the items (this means that the count will be nostrictly ascending)
	for(my $a=$#all_items;$a >= 0 ; $a--)
		{	
		# Make sure that the above ascertion is true. If not, return 0.	
		if($check_count > $all_items[$a]->count)
			{
			$self->{err} = "Frequency table not accurate. [$check_count " . $all_items[$a]->count . "]";
			return 0;
			}
		
		# Set check_count to be the the current items count.
		$check_count = $all_items[$a]->count;
		
		# Get a hash (ref) containing all the patterns formed by the current 'item name'
		my $pattern_hash = $self->get_patterns($all_items[$a]->item_name);

		# If pattern hash is undefined or empty, then either $all_items[$a]->item_name was null, or (more likely) the
		# FP-Tree had not been loaded with the full compliment of data, i.e. transactions that contained #item name#
		# had not inserted into the FP-Tree. In either case, association rules would not be valid so return 0.
		unless($pattern_hash)
			{
			$self->{err} = "Item '". $all_items[$a]->item_name . "' created no patterns. FP-Tree may not have been loaded with complete data set.";
			return 0;
			}
		
		# For each of these patterns..
		foreach my $key (keys %{ $pattern_hash })
			{
			# If the pattern is at or above the minimum support count
			unless($pattern_hash->{$key}->{count} < $support_count)
				{
				# Add pattern to the pattern hash for the FP-Tree
				$self->{patterns}->{$key} = $pattern_hash->{$key};
				
				# And see if the pattern has a length greater than any other pattern seen so far. If so, adjust the 
				# FP-Tree's max pattern length property.
				my $pat_len = scalar(@{$self->{patterns}->{$key}->{pattern}});
				$self->{max_pattern_len} = $self->{max_pattern_len} < $pat_len?$pat_len:$self->{max_pattern_len};
				}
			
			}
		}
	# If we got to this point, everything when well so return 1.
	1;
	}		


# Function retrieves all patterns in the FP-Tree that have 'item name' as their suffix.
# Parameters:
# 	1. 'item name'
# Returns:
#	Hash reference containing all patterns generated from 'item name' if successful, undefined or empty if something went wrong.
sub get_patterns
	{
	my $self = shift;
	my $item_name = shift;
	
	# If no item name provided, then nothing to do
	unless($item_name)
		{
		return undef;
		}
	
	# Initialized hash ref that will contain all the patterns discovered for this item name
	my $pattern_hash = {};	
	
	# Get the pointer to the first node in the FP-Tree with label #item name# from the header table.
	my $item_ptr = $self->{header_table}->{$item_name}->{sibling};
	
	# While the item pointer continues to point to a valid FP-Tree node..
	while($item_ptr)
		{
		# Create an array of items, beginning with the current item, followed by the prefix
		# OF THIS NODE. In other words, only get the items between this node and the root node.
		my @combo = (
			$item_ptr->item_name, 
			$item_ptr->get_prefix($self->root) # This is the get_prefix method of the FP_Tree_node object, see below for usage.
			);
		
		# Store the patterns formed from this item set in the pattern hash.				
		&store_combinations($pattern_hash, $item_ptr->count, @combo);
		
		# Set the item pointer to be the next node of the name item name
		$item_ptr = $item_ptr->{sibling};
		}
	
	$pattern_hash;
	}


# Function stores all combinations of given pattern into hash ref.
# Parameters
# 	1. Hash ref used for storage
#	2. The number of times this complete pattern was encountered
#	3. An array containing the elements of the pattern, starting with the suffix.
# Returns
#	Function does not return any value of importance, all work is done on the hash ref.
sub store_combinations
	{
	my $combo_hash = shift;
	my $combo_num = shift;
	my $suffix = $_[0];
	
	# Get all the combinations for this pattern. Make sure to only get those that start off with the suffix.
	my @combos = grep {$_->[0] eq $suffix} @{&combinations(@_)};

	# For each combo pattern
	foreach(@combos)
		{
		# Join the array with '~' to form string representation of pattern.
		my $pattern = join '~', @$_;
	
		# If the hash already contains this pattern..
		if($combo_hash->{$pattern})
			{
			# ... then increment the 'count' field of the pattern.
			$combo_hash->{$pattern}->{count} += $combo_num;
			}
		else
			{
			# ... otherwise, set the 'pattern' field of the storing hash ref to be a hash ref with field count (containing count)
			# and pattern (containing ref to array containing the individual items of the pattern.
			$combo_hash->{$pattern} = {count => $combo_num, pattern => $_};
			}
		}	
	}
	
	
# Function finds all combinations of a given pattern.
# Parameters
# 	1. The first item of the pattern
#	2. Array containing the rest of the items
# Returns
#	Array ref where each element is itself an array ref representing the pattern generated.
sub combinations 
	{
	# By shifting the first element off the input array, we guarantee that the function will eventually exit
	my $first = shift;
	
	# If nothing got shifted off, that means nothing left so return an empty array ref
	unless($first)
		{
		return [];
		}	
	
	my @new_combos = ([$first]);
	
	# This is the recursive step. Get all the combinations of what remains of the pattern array passed to the funciton.
	my @found_combos = @{&combinations(@_)};
	
	# Push these found combos onto the new combo array
	push @new_combos, @found_combos;
	
	# Then for each of the elements of the found combos, push a new array ref onto the new combos array that starts off
	# with the first element, and then has the sub pattern after it.
	foreach (@found_combos)
		{
		push @new_combos, [$first,@$_];
		}

	# Return a ref to the new combos array
	return \@new_combos;
	}
	
	
# The following is an FP_Tree_node object, the main building block of FP-Trees (also see FP_Tree_header_node below).
{
	package FP_Tree_node;
	
	# Node constructor.
	# Parameters
	# 	1. Name of the item [optional, but only if constructing a root node]
	#	2. Parent, an FP_Tree_node [optional, but only if constructing a root node]
	sub new
		{
		my $class = shift;
		my $item_name = shift;
		my $parent = shift;
		
		# For now (v 0.01) only check that if an item name is passed that the node also has a parent. 
		if($item_name && !$parent)
			{
			return undef;
			}
		
		my $self = {
					item_name => $item_name,
					parent => $parent,
					sibling => undef, # This is a pointer to the next FP_Tree_node with the same item name label.
					child_nodes => {}, # Hash ref to all child nodes of this node.
					count => 1, # Number of times this node has been traversed. Creation counts as one traversal.
					used => 0, # Number of times this node has been read.
					err => '' # Stores any error messages related to this node.				
					};
		bless $self, $class;
		}
	
	# Returns name of the item
	sub item_name
		{
		my $self = shift;
		$self->{item_name};
		}	
		
	# Function gets prefix of current node. In other words, it gets the item name labels of all nodes above it
	# in the same branch of the FP-Tree.
	# Parameters:
	# 	1. Root FP_Tree_node
	# Returns:
	#	Array containing all the item names, in the order they were encountered.
	sub get_prefix
		{
		my $self = shift;
		my $root = shift;
		
		# Only check to make sure that self and root are not the same.  For now (v 0.01) assume that only FP_Tree_nodes
		# are going to be passed.
		if($self == $root)
			{
			$self->{err} = "'get_prefix' called on self or incorrect root provided";
			return 0;
			}
		
		# Get the adjusted count for this node.
		my $count = $self->adj_count;
		# Increase one's own count by this amount.
		$self->inc_used($count);
		
		my @pattern;
		# Set the next node pointer to the parent of the current node.
		my $parent_node = $self->{parent};
		# While a parent is not the root of the tree...
		while($parent_node != $root)
			{
			# Push the parent's item name onto the pattern array.
			push @pattern, $parent_node->item_name;
			# Increment the parent's used count by the adjusted count of the node get_prefix was called on.
			unless($parent_node->inc_used($count))
				{
				# Unlikely but if somehow parent is not a FP_Tree_node or if somebody hacked together a cyclic tree
				$self->{err} = "Error occured while attempting to increment count of ancestor of " . $self->item_name . " [" . $parent_node->item_name . "]";
				return 0;
				}
			# Set the next node pointer to its parent
			$parent_node = $parent_node->{parent};
			}
		
		unless(@pattern)
			{
			$self->{err} = 'No pattern generated';
			}
		
		# Return the pattern array;
		return @pattern;
		}	
	
	# Method resets the 'used' property of the node to zero, and calls itself on the sibling of the node (if one exists).
	sub reset_used
		{
		my $self = shift;
		$self->{used} = 0;
		
		if($self->{sibling})
			{
			$self->{sibling}->reset_used;
			}
		}
	
	
	# Method returns the adjusted count of the node.  This is the number of times node was traversed minus the number of times
	# it has been read (since last reset).
	sub adj_count
		{
		my $self = shift;
		$self->count - $self->used;
		}
	
	# Method returns the number of times a node has been read.
	sub used
		{
		my $self = shift;
		$self->{used};
		}	
		
	# Method increments the number of times that a node has been read.
	# Parameters:
	# 	1. Positive integer reflecting number of times node read.
	# Returns:
	# 	1 if increment was successful, and 0 if the read count exceeded the traversal count.
	sub inc_used
		{
		my $self = shift;
		my $by = shift;
		if($by && $by > 0)
			{
			$self->{used} += $by;
			}
		
		if($self->{used} > $self->{count})
			{
			$self->{err} =  "Node read more times than written [FP_Tree_node : " . $self->item_name," " . $self->{used} .  " " . $self->{count} . "]";
			return 0;
			}
		
		return 1;
		}
	
	# Method returns number of children a node has
	sub children
		{
		my $self = shift;
		scalar(keys %{$self->{child_nodes}});
		}
	
	# Method used to determine whether node has a child by a particular name
	# Parameters:
	# 	1. Name of child looked for (string corresponding to item name)
	# Returns
	#	The child if one is found, or undef if not.
	sub child_exists
		{
		my $self = shift;
		my $looking_for = shift;
		
		$self->{child_nodes}->{$looking_for};
		}
		
	# Method adds child to a node.
	# Parameters:
	#	1. Item name (string).
	# Returns:
	#	New child node or undef if: 1. no name specified, 2. a child with that name already exists (do not want to overwrite
	# 	children under any circumstances, or 3. FP_Tree_node creation was unsuccessful.
	sub add_child
		{
		my $self = shift;
		my $child_name = shift;

		unless($child_name && !$self->child_exists($child_name))
			{return undef;}
		
		$self->{child_nodes}->{$child_name} = FP_Tree_node->new($child_name,$self);
		}
		
	# Returns the sibling of the node	
	sub sibling
		{
		my $self = shift;
		$self->{sibling};
		}
	
	# Sets the sibling of the node
	# Parameters:
	#	1. An FP_Tree_node
	# Returns:
	#	1 if successful, 0 otherwise	
	sub set_sibling
		{
		my $self = shift;	
		my $sibling = shift;
		
		if($sibling->item_name eq $self->item_name)
			{	
			$self->{sibling} = $sibling;
			return 1;
			}
			
		$self->{err} = "Sibling 'item name' label not the same as own item name [ sib: " . $sibling->item_name . ", self: " . $self->item_name . " ]";
		return 0;
		}
	
	# Returns node's count
	sub count
		{
		my $self = shift;
		$self->{count};
		}
	
	# Increments the node's count.
	# Parameters:
	# 	None
	# Returns
	# 	Newly adjusted count
	sub inc_count
		{
		my $self = shift;
		++$self->{count};
		}
		
	# Returns the node's error string
	sub err
		{
		my $self = shift;
		$self->{err};
		}
}


# The following is an FP_Tree_header_node object, a component of FP-Trees.
{
	package FP_Tree_header_node;
	
	# Node constructor
	# Parameters
	#	1. Item name (string)
	#	2. Rank (positive integer, reflecting relative rank, higher number, lower rank)
	# Returns
	#	an FP_Tree_header_node or undef if incorrect parameters were supplied.
	sub new
		{
		my $class = shift;
		my $item_name = shift;
		my $rank = shift;
		
		unless($item_name && $rank && $rank > 0)
			{
			return undef;
			}
		
			
		my $self = {
					item_name => $item_name,
					sibling => undef, # Pointer to the first FP_Tree_node with label #item name# in the FP-Tree.
					rank => $rank,
					count => 0, # Total number of transactions that included #item name#
					err => ''
					};
					
		bless $self, $class;
		}
	
	# Returns the rank of the node
	sub rank
		{
		my $self = shift;
		$self->{rank};
		}
	
	# Returns the item name label of the node
	sub item_name
		{
		my $self = shift;
		$self->{item_name};
		}	
	
	# Returns error
	sub err
		{
		my $self = shift;
		$self->{err};
		}
	
	# Returns the pointer to the first FP_Tree_node with label #item name# in the FP-Tree.
	sub sibling
		{
		my $self = shift;
		$self->{sibling};
		}
	
	# Sets the sibling of the node
	# Parameters:
	#	1. An FP_Tree_node
	# Returns:
	#	1 if successful, 0 otherwise	 
	sub set_sibling
		{
		my $self = shift;
		my $sibling = shift;
		
		if($sibling->item_name eq $self->item_name)
			{	
			$self->{sibling} = $sibling;
			return 1;
			}
			
		$self->{err} = "Sibling 'item name' label not the same as own item name [ sib: " . $sibling->item_name . ", self: " . $self->item_name . " ]";
		return 0;
		}
	
	# Increments the node's count.
	# Parameters:
	# 	None
	# Returns
	# 	Newly adjusted count
	sub inc_count
		{
		my $self = shift;
		++$self->{count};
		}
		
	# Returns node's count
	sub count
		{
		my $self = shift;
		$self->{count};
		}
}

# The following is an FP_Tree_association_rule object used for creating/storing association rules generated from FPGROWTH
# Note: no part of an FP_Tree_association_rule object can be changed after it is created.
{
	package FP_Tree_association_rule;
	
	# Constructor of FP_Tree_association_rule
	# Parameters:
	#	1. Left side of association rule (a pattern array ref)
	#	2. Right side of association rule (a pattern array ref)
	#	3. Support of association rule (percentage, given as a decimal)
	#	4. Confidence of assocciation rule (percentage, given as a decimal)
	# Returns
	#	A new FP_Tree_association_rule if successful, undef if all parameters were not passed correctly
	sub new
		{
		my $class = shift;
		my $left = shift;
		my $right = shift;
		my $support = shift;
		my $confidence = shift;
		
		unless($left && ref $left && $right && ref $right && $support && $confidence)
			{
			return undef;
			}
		
		if($support <= 0 || $support > 1 || $confidence <= 0 || $confidence > 1)
			{
			return undef;
			}
		
		my $self = {
					left => $left,
					right => $right,
					support => $support,
					confidence => $confidence
					};
					
		bless $self, $class;
		}
		
	# Returns left side of association rule (a pattern array ref)
	sub left
		{
		my $self = shift;
		@{$self->{left}};
		}
	
	# Returns right side of association rule (a pattern array ref)
	sub right
		{
		my $self = shift;
		@{$self->{right}};
		}
		
	# Returns support of association rule (percentage, given as a decimal)
	sub support
		{
		my $self = shift;
		$self->{support};
		}
		
	# Returns confidence of assocciation rule (percentage, given as a decimal)
	sub confidence
		{
		my $self = shift;
		$self->{confidence};
		}
		
}

1;

__END__

=head1 NAME
TREE::FP - Perl implementation of the FP-Tree

=head1 SYNOPSIS
	use Tree:FP;
	
	$fptree = Tree::FP->new('a','b','c');
	
	$insert_successful = $fptree->insert_tree('c','a','b');
	
	$decimal_support = $fptree->support;
	$fptree->set_support(0.3);
	
	$decimal_confidence = $fptree->confidence;
	$fptree->set_confidence(0.25);
	
	@rules = $fptree->association_rules;
	
	$fptree->reset_tree;
	
	$error_string = $fptree->err;
	
=head1 DESCRIPTION

Tree:FP is a Perl implmentation of the FP-Tree based association rule mining algorithm (association rules == market basket analysis). For a detailed explanation, see "Mining Frequent Patterns without Candidate Generation" by Jiawei Han, Jian Pei, and Yiwen Yin, 2000. Contrarywise, most books on data mining will have information on this algorithm.

The short version is this: instead of generating a huge number of candidate sets for the apriori algorithm and requiring multiple database scans, compress information into a new data structure, a Frequent Pattern (or FP) tree, then mine the tree.

=head1 METHODS

=head2 new( LIST )
The new method is called with a list of frequent items from the transactional database listed in descending support order.
Given the following DB
	Item | Count
	------------
	itm1 | 2
	itm2 | 4
	itm3 | 3
	itm4 | 5
	itm5 | 3
The code for creating a new FP-Tree would be:
	$fptree = Tree::FP->new('itm4','itm2','itm3','itm5','itm1');

NOTE: The list can also be of integers, which is the more likely scenario for most TDBs.
	
=head2 insert_tree( LIST )
This is the method used to populate the FP-Tree.  The list consists of all items for one transaction. The items need NOT be in any order. The method returns 0 (false) is an error occurred, and 1 (true) otherwise.
Example:
	$fptree->insert_tree('itm1','itm2','itm3');
	
=head2 support()
Returns the current minimum percentage support for the FP-tree, expressed as a decimal. 10% = 0.1

=head2 set_support( FLOAT )
Sets the current minimum percentage support for the FP-tree.

=head2 confidence()
Returns the current minimum percentage confidence for the FP-tree, expressed as a decimal. 10% = 0.1
NOTE: Currently this method has no effect on performance of the FP-Tree. Future versions may allow result filtering based on confidence.

=head2 set_confidence( FLOAT )
Sets the current minimum percentage confidence for the FP-tree.

=head2 association_rules()
Returns list of assocation rules for the FP-Tree meeting minimum support, listed in descending order of confidence.  Each element of the list is actually an FP_Tree_association_rule object with the following four methods:
	left - returns left side of association rule (a "pattern") as a list, each element of which is an item
	right - returns right side of association rule (a "pattern") as a list, each element of which is an item
	support - support for the rule
	confidence - confidence for the rule

Example:
	@rules = $fptree->association_rules;
	@left = $rules[0]->left;
	@right = $rules[0]->right;
	$support = $rules[0]->support;
	$confidence = $rules[0]->confidence;

=head2 reset_tree()
When resetting the support level of the FP-Tree, it is necessary to call the reset_tree method to clear the previously mined patterns. This is not called from the set_support method as it is entirely possible that with a user interface, the support may be changed several times before the tree is mined. While the reset_tree method is not computationally intensive, it is not free either.

=head2 err()
Returns the last error that occurred in the FP-Tree. In general, if any of the methods returns false (0 or undef), this method will provide details as to what went wrong.

=head1 NOTES
This package includes three other packages, namely FP_Tree_node, FP_Tree_header_node, and FP_Tree_association_rule. Outside of the context of an FP-Tree, it is not likely that they have much utility, however feel free to use these.  Also, there is a combinations function in this package that can be used for finding all combinations of elements of an array (but this must be explicitly exported).

=head1 AUTHOR
Martin Paczynski, nitram@cpan.org. 

=head1 COPYRIGHT

Copyright 2003, Martin Paczynski, nitram@cpan.org, all rights reserved.

This package is free software and is provided "as is" without express or
implied warranty.  It may be used, redistributed and/or modified under the
same terms as Perl itself.

=cut
